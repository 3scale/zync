# frozen_string_literal: true

module Prometheus

  ## ActiveJob Subscriber to record Prometheus metrics.
  ## Those metrics are per process, so they have to be aggregated by Prometheus.
  class ActiveJobSubscriber < ActiveSupport::Subscriber
    Yabeda.configure do
      group :que do
        counter :job_retries_total, comment: 'A number of Jobs retried by this process'
        counter :job_failures_total, comment: 'A number of Jobs errored by this process'
        counter :job_performed_total, comment: 'A number of Jobs performed by this process'
        counter :job_enqueued_total, comment: 'A number of Jobs enqueued by this process'
        histogram :job_duration_seconds do
          comment 'A histogram of Jobs perform times by this process'
          buckets false
        end
        # summary :job_runtime_seconds, comment: 'A summary of Jobs perform times'
      end
    end

    def initialize
      super
      @metrics = Yabeda.que
      @job_runtime_seconds = Yabeda::Prometheus.registry.summary(:que_job_runtime_seconds, 'A summary of Jobs perform times')
    end

    def enqueue(event)
      payload = event.payload
      labels = extract_labels(payload)

      if payload.fetch(:job).executions == 0
        job_enqueued_total.increment(labels)
      else
        job_retries_total.increment(labels)
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
      duration = event.duration / 1000.0

      job_duration_seconds.measure(labels, duration)
      job_runtime_seconds.observe(labels, duration)
    end

    def observe_perform(payload, labels)
      ex = payload[:exception_object]

      if ex
        # not measuring failed job duration, but we could
        job_failures_total.increment(labels)
      else
        job_performed_total.increment(labels)
      end
    end

    def extract_labels(payload)
      {
          adapter: payload.fetch(:adapter).class.name.demodulize.remove('Adapter'),
          job_name: payload.fetch(:job).class.name
      }
    end

    delegate :job_duration_seconds, :job_enqueued_total, :job_performed_total, :job_failures_total, :job_retries_total,
             to: :@metrics

    attr_reader :job_runtime_seconds

    attach_to :active_job
  end
end
