# frozen_string_literal: true

require 'lograge/subscriber_base'

module Lograge
  # Log Subscriber for ActiveJob. Replaces Rails default subscriber.

  class JobLogSubscriber < ActiveSupport::LogSubscriber
    # To be included in ActiveJob::Base to turn off tagged logging.
    module Logging
      private

      def tag_logger(*)
        yield
      end
    end

    include Lograge::SubscriberBase

    log_event :enqueue
    log_event :enqueue_at
    log_event :perform

    private

    def merge_data(data, event, payload)
      super
      data.merge!(extract_schedule(payload))
    end

    def initial_data(payload)
      job = payload.fetch(:job)

      {
        adapter: extract_adapter(payload),
        job: job.class.name,
        priority: job.priority,
        queue: job.queue_name,
        arguments: extract_arguments(job),
      }
    end

    def extract_schedule(payload)
      scheduled_at = payload.fetch(:job).scheduled_at or return EMPTY_DATA

      { scheduled_at: Time.at(scheduled_at).utc }
    end

    def extract_adapter(payload)
      payload.fetch(:adapter).class.name.demodulize.remove('Adapter')
    end

    def extract_arguments(job)
      job.arguments.map { |arg| format_arg(arg) }
    end

    def format_arg(arg)
      case arg
      when Hash
        arg.transform_values { |value| format_arg(value) }
      when Array
        arg.map { |value| format_arg(value) }
      when GlobalID::Identification
        arg.to_global_id.to_s rescue arg
      else
        arg
      end
    end
  end
end
