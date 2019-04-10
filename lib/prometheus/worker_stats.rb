# frozen_string_literal: true

module Prometheus
  # Prometheus metric to get job stats from Que.
  class WorkerStats < Prometheus::Client::Metric
    def type
      :gauge
    end

    def values
      synchronize do
        {
            {} => job_stats.fetch('workers')
        }
      end
    end

    protected

    DEFAULT_STATEMENT_TIMEOUT = 'SET LOCAL statement_timeout TO DEFAULT'
    READ_ONLY_TRANSACTION =  'SET TRANSACTION ISOLATION LEVEL SERIALIZABLE READ ONLY DEFERRABLE'

    SQL = <<~SQL
      SELECT SUM(worker_count) AS workers, COUNT(*) AS nodes FROM que_lockers
    SQL

    def job_stats
      connection = ActiveRecord::Base.connection

      connection.transaction do
        connection.execute(DEFAULT_STATEMENT_TIMEOUT)
        connection.execute(READ_ONLY_TRANSACTION)
        connection.select_one(SQL)
      end
    end
  end
end
