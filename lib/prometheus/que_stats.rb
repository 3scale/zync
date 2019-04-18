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

    def job_stats(filter = nil)
      filter = "WHERE #{filter}" if filter
      sql = <<~SQL
        SELECT args->0->>'job_class' AS job_class, COUNT(*) as count
        FROM que_jobs #{filter}
        GROUP BY args->0->>'job_class'
      SQL

      execute do |connection|
        connection.select_all(sql)
      end
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
    workers = gauge :workers_total,  comment: 'Que Workers running'

    collect do
      Prometheus::QueStats.job_stats.each do |stats|
        scheduled_jobs.set({ job: stats.fetch('job_class') }, stats.fetch('count'))
      end

      Prometheus::QueStats.job_stats(%q[(args->0->>'retries')::integer > 0]).each do |stats|
        scheduled_jobs.set({ job: stats.fetch('job_class'), type: 'retry' }, stats.fetch('count'))
      end

      Prometheus::QueStats.job_stats('run_at < now()').each do |stats|
        scheduled_jobs.set({ job: stats.fetch('job_class'), type: 'scheduled' }, stats.fetch('count'))
      end

      Prometheus::QueStats.job_stats('run_at > now()').each do |stats|
        scheduled_jobs.set({ job: stats.fetch('job_class'), type: 'future' }, stats.fetch('count'))
      end

      workers.set({ }, Prometheus::QueStats.worker_stats.fetch('workers'))
    end
  end
end

