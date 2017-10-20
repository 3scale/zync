# frozen_string_literal: true
require 'prometheus/client/metric'

module Prometheus

  # Prometheus metric to get job stats from Que.
  class JobStats < Prometheus::Client::Metric

    def initialize(*)
      super
      @filter = nil
    end

    CTE = <<~SQL
      WITH jobs AS (
          SELECT *, args::jsonb -> 0 AS options FROM que_jobs
      ),
       jobs_list AS (
      SELECT options->>'job_class' AS job,
      options->>'job_id' AS job_uuid,
      (options->>'executions')::integer AS retries,
      options->'arguments' AS arguments,
      run_at, job_id FROM jobs
      )
    SQL

    def type
      :job_stats
    end

    def filter(sql)
      @filter = sql
    end

    def values
      synchronize do
        job_stats.map do |summary|
          [ { job: summary.fetch('job') }, summary.fetch('count') ]
        end.to_h
      end
    end

    protected

    DEFAULT_STATEMENT_TIMEOUT = 'SET LOCAL statement_timeout TO DEFAULT'
    READ_ONLY_TRANSACTION =  'SET TRANSACTION ISOLATION LEVEL SERIALIZABLE READ ONLY DEFERRABLE'

    def job_stats
      connection = ActiveRecord::Base.connection

      filter = "WHERE #{@filter}" if @filter
      sql = <<~SQL
          SELECT job, COUNT(*) FROM jobs_list #{filter} GROUP BY job
      SQL

      connection.transaction do
        connection.execute(DEFAULT_STATEMENT_TIMEOUT)
        connection.execute(READ_ONLY_TRANSACTION)
        connection.select_all(CTE + sql)
      end
    end
  end
end
