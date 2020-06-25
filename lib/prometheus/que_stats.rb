# frozen_string_literal: true
require 'prometheus/client/metric'
require 'que/active_record/model'

module Prometheus
  # Prometheus metric to get job stats from Que.
  module QueStats
    mattr_accessor :read_only_transaction, default: true, instance_accessor: false

    class Stats
      def call
        raise NoMethodError, __method__
      end

      protected

      DEFAULT_STATEMENT_TIMEOUT = 'SET LOCAL statement_timeout TO DEFAULT'
      READ_ONLY_TRANSACTION =  'SET TRANSACTION ISOLATION LEVEL SERIALIZABLE READ ONLY DEFERRABLE'

      def execute
        connection.transaction(requires_new: true, joinable: false) do
          connection.execute(DEFAULT_STATEMENT_TIMEOUT)
          connection.execute(READ_ONLY_TRANSACTION) if Prometheus::QueStats.read_only_transaction
          yield connection
        end
      end

      delegate :connection, to: ActiveRecord::Base.name
    end

    class WorkerStats < Stats
      WORKER_STATS = <<~SQL
        SELECT SUM(worker_count) AS workers_count, COUNT(*) AS nodes_count FROM que_lockers
      SQL
      private_constant :WORKER_STATS

      def call
        execute do |connection|
          connection.select_one(WORKER_STATS)
        end
      end

      def workers
        call.fetch('workers_count')
      end

      alias_method :all, :workers

      def nodes
        call.fetch('nodes_count')
      end
    end

    class JobStats < Stats
      def initialize
        @job_classes_table = Arel::Table.new(:jobs)
        @stats_count_table = Arel::Table.new(:stats)
      end

      attr_reader :job_classes_table, :stats_count_table

      def call(*filters)
        filtered_stats_count_relation = filters.reduce(build_stats_count_relation) { |relation, filter| relation.where(filter) }
        common_tables = [job_classes_arel, Arel::Nodes::As.new(stats_count_table, filtered_stats_count_relation.arel)]

        relation = job_classes_table.join(stats_count_table, Arel::Nodes::OuterJoin).
          on(job_class_column.eq(stats_count_table[JOB_CLASS_COLUMN_NAME])).
          project([job_class_column, Arel::Nodes::NamedFunction.new('coalesce', [stats_count_table['count'], 0]).as('count')]).
          with(common_tables)

        execute do |connection|
          connection.select_all(relation.to_sql)
        end
      end

      alias_method :all, :call

      def ready
        conditions = [['error_count = ?', 0], { expired_at: nil, finished_at: nil }, ['run_at <= ?', Time.zone.now]]
        call(*conditions)
      end

      def scheduled
        call(['error_count = ?', 0], ['run_at > ?', Time.zone.now])
      end

      def finished
        call('finished_at IS NOT NULL')
      end

      def failed
        call(['error_count > ?', 0], { expired_at: nil })
      end

      def expired
        call('expired_at IS NOT NULL')
      end

      protected

      # ApplicationJob did not have to be here, but it's just harder to test otherwise because of ApplicationJob#delete_duplicates
      JOB_CLASSES = %w[ApplicationJob ProcessEntryJob ProcessIntegrationEntryJob UpdateJob].inspect.tr('"', "'").freeze
      private_constant :JOB_CLASSES

      JOB_CLASS_COLUMN_NAME = 'job'
      private_constant :JOB_CLASS_COLUMN_NAME

      def job_class_column
        @job_classes_table[JOB_CLASS_COLUMN_NAME]
      end

      def job_classes_arel
        @job_classes_arel ||= begin
          job_classes = Arel.sql("SELECT unnest(ARRAY#{JOB_CLASSES})").as(JOB_CLASS_COLUMN_NAME)
          Arel::Nodes::As.new(job_classes_table, Arel.sql("(#{job_classes.to_sql})"))
        end
      end

      def build_stats_count_relation
        Que::ActiveRecord::Model.selecting { [Arel.sql("args->0->>'job_class'").as(JOB_CLASS_COLUMN_NAME), Arel.star.count.as('count')] }.group("args->0->>'job_class'")
      end
    end

    class StatsCollector
      def initialize(gauge, stats)
        @gauge = gauge
        @stats = stats
      end

      attr_reader :gauge, :stats

      def call(type = nil)
        type_hash, stats_count = type_hash_and_stats_count(type)
        gauge.set({ }.merge(type_hash), stats_count)
      end

      protected

      def type_hash_and_stats_count(type)
        type_hash = type ? { type: type } : {}
        stats_count = stats.public_send(type ? type : :all)
        [type_hash, stats_count]
      end
    end

    class GroupedStatsCollector < StatsCollector
      def initialize(gauge, stats, grouped_by:)
        super(gauge, stats)
        @grouped_by = grouped_by
      end

      attr_reader :grouped_by

      def call(type = nil)
        type_hash, grouped_stats_count = type_hash_and_stats_count(type)
        grouped_stats_count.each do |stats_count|
          gauge.set({ grouped_by => stats_count.fetch(grouped_by) }.merge(type_hash), stats_count.fetch('count'))
        end
      end
    end
  end
end

Yabeda.configure do
  group :que do
    workers = gauge :workers_total, comment: 'Que Workers running'
    worker_stats = Prometheus::QueStats::WorkerStats.new
    collector = Prometheus::QueStats::StatsCollector.new(workers, worker_stats)
    collect(&collector.method(:call))
  end
end

Yabeda.configure do
  group :que do
    jobs = gauge :jobs_scheduled_total, comment: 'Que Jobs to be executed'
    job_stats = Prometheus::QueStats::JobStats.new
    collector = Prometheus::QueStats::GroupedStatsCollector.new(jobs, job_stats, grouped_by: 'job')
    collect do
      collector.call
      %w[ready scheduled finished failed expired].each(&collector.method(:call))
    end
  end
end
