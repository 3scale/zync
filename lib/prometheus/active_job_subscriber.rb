# frozen_string_literal: true

module Prometheus

  ## ActiveJob Subscriber to record Prometheus metrics.
  ## Those metrics are per process, so they have to be aggregated by Prometheus.
  class ActiveJobSubscriber < ActiveSupport::Subscriber

    prometheus = Prometheus::Client.registry or raise 'Missing Prometheus client registry'

    metrics = {
        retried_jobs: prometheus.counter(:zync_job_retries, 'A number of Jobs retried'),
        failed_jobs: prometheus.counter(:zync_failed_jobs, 'A number of Jobs errored'),
        performed_jobs: prometheus.counter(:zync_performed_jobs, 'A number of Jobs performed'),
        enqueued_jobs: prometheus.counter(:zync_enqueued_jobs, 'A number of Jobs enqueued'),
        histogram: prometheus.histogram(:zync_jobs_histogram, 'A histogram of Jobs perform times'),
        summary: prometheus.summary(:zync_jobs_summary, 'A summary of Jobs perform times'),
    }
    METRICS = OpenStruct.new(metrics).freeze

    def initialize
      super
      @metrics = METRICS
    end

    def enqueue(event)
      payload = event.payload
      labels = extract_labels(payload)

      if payload.fetch(:job).executions == 0
        enqueued_jobs.increment(labels)
      else
        retried_jobs.increment(labels)
      end
    end

    alias enqueue_at enqueue

    def perform(event)
      payload = event.payload
      labels = extract_labels(payload)

      observe_perform(payload, labels)
      observe_duration(event, labels)
    end

    private

    def observe_duration(event, labels)
      duration = event.duration

      histogram.observe(labels, duration)
      summary.observe(labels, duration)
    end

    def observe_perform(payload, labels)
      ex = payload[:exception_object]

      if ex
        # not measuring failed job duration, but we could
        failed_jobs.increment(labels)
      else
        performed_jobs.increment(labels)
      end
    end

    def extract_labels(payload)
      {
          adapter: payload.fetch(:adapter).class.name.demodulize.remove('Adapter'),
          job_name: payload.fetch(:job).class.name
      }
    end

    delegate :performed_jobs, :enqueued_jobs, :retried_jobs, :histogram, :summary, :failed_jobs,
             to: :@metrics

    attach_to :active_job
  end
end
