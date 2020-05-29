# frozen_string_literal: true
require 'prometheus/client/metric'
require 'que/active_record/model'

module Prometheus

  # Prometheus metric to get job stats from Que.
  module QueStats
    module_function

    WORKER_STATS = <<~SQL
      SELECT SUM(worker_count) AS workers, COUNT(*) AS nodes FROM que_lockers
    SQL

    def worker_stats
      execute do |connection|
        connection.select_one(WORKER_STATS)
      end
    end

    # ApplicationJob did not have to be here, but it's just harder to test otherwise because of ApplicationJob#delete_duplicates
    JOB_CLASSES = %w[ApplicationJob ProcessEntryJob ProcessIntegrationEntryJob UpdateJob].inspect.tr('"', "'").freeze

    def job_stats(*filters)
      job_classes_expression = Arel.sql("SELECT unnest(ARRAY#{JOB_CLASSES})").as('job_class')
      job_classes_table = Arel::Table.new(:jobs)
      job_class_column = job_classes_table['job_class']

      stats_count_relation = Que::ActiveRecord::Model.selecting { [Arel.sql("args->0->>'job_class'").as('job_class'), Arel.star.count.as('count')] }.group("args->0->>'job_class'")
      stats_count_relation = filters.reduce(stats_count_relation) { |relation, filter| relation.where(filter) }
      stats_count_table = Arel::Table.new(:stats)

      relation = job_classes_table.join(stats_count_table, Arel::Nodes::OuterJoin).
                                   on(job_class_column.eq(stats_count_table['job_class'])).
                                   project([job_class_column, Arel::Nodes::NamedFunction.new('coalesce', [stats_count_table['count'], 0]).as('count')]).
                                   with([
        Arel::Nodes::As.new(job_classes_table, Arel.sql("(#{job_classes_expression.to_sql})")),
        Arel::Nodes::As.new(stats_count_table, stats_count_relation.arel)
      ])

      execute do |connection|
        connection.select_all(relation.to_sql)
      end
    end

    def job_stats_ready
      conditions = [['error_count = ?', 0], { expired_at: nil, finished_at: nil }, ['run_at <= ?', Time.zone.now]]
      job_stats(*conditions)
    end

    def job_stats_scheduled
      job_stats(['run_at > ?', Time.zone.now])
    end

    def job_stats_finished
      job_stats('finished_at IS NOT NULL')
    end

    def job_stats_retried
      job_stats(["(args->0->>'retries')::integer > ?", 0])
    end

    def job_stats_failed
      job_stats(['error_count > ?', 0])
    end

    mattr_accessor :read_only_transaction, default: true, instance_accessor: false

    class << self
      protected

      def execute
        connection.transaction(requires_new: true, joinable: false) do
          connection.execute(DEFAULT_STATEMENT_TIMEOUT)
          connection.execute(READ_ONLY_TRANSACTION) if read_only_transaction
          yield connection
        end
      end

      delegate :connection, to: ActiveRecord::Base.name
    end

    DEFAULT_STATEMENT_TIMEOUT = 'SET LOCAL statement_timeout TO DEFAULT'
    READ_ONLY_TRANSACTION =  'SET TRANSACTION ISOLATION LEVEL SERIALIZABLE READ ONLY DEFERRABLE'
  end
end

Yabeda.configure do
  group :que do
    scheduled_jobs = gauge :jobs_scheduled_total, comment: 'Que Jobs to be executed'
    workers = gauge :workers_total, comment: 'Que Workers running'

    set_stats = ->(type, stats) { scheduled_jobs.set({ job: stats.fetch('job_class') }.merge(type), stats.fetch('count')) }

    collect do
      set_stats_all = set_stats.curry.call({})
      Prometheus::QueStats.job_stats.each(&set_stats_all)

      %w[ready scheduled finished retried failed].each do |type|
        set_stats_type = set_stats.curry.call(type: type)
        Prometheus::QueStats.public_send("job_stats_#{type}").each(&set_stats_type)
      end

      workers.set({ }, Prometheus::QueStats.worker_stats.fetch('workers'))
    end
  end
end

