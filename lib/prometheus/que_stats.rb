# frozen_string_literal: true
require 'prometheus/client/metric'

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
      filter = "WHERE #{filters.join(' AND ')}" if filters.presence
      sql = <<~SQL
        WITH
          jobs AS (SELECT unnest(array#{JOB_CLASSES}) AS job_class),
          stats AS (
            SELECT args->0->>'job_class' AS job_class, COUNT(*) as count
            FROM que_jobs #{filter}
            GROUP BY args->0->>'job_class'
          )
        SELECT jobs.job_class, COALESCE(stats.count, 0) AS count
        FROM jobs LEFT JOIN stats ON jobs.job_class = stats.job_class
      SQL

      execute do |connection|
        connection.select_all(sql)
      end
    end

    def job_stats_ready
      job_stats('error_count = 0', 'expired_at IS NULL', 'finished_at IS NULL', 'run_at <= now()')
    end

    def job_stats_scheduled
      job_stats('run_at > now()')
    end

    def job_stats_finished
      job_stats('finished_at IS NOT NULL')
    end

    def job_stats_retried
      job_stats(%q[(args->0->>'retries')::integer > 0])
    end

    def job_stats_failed
      job_stats('error_count > 0')
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

