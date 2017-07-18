# frozen_string_literal: true

module Lograge
  class JobLogSubscriber < ActiveSupport::LogSubscriber
    module Logging
      private

      def tag_logger(*)
        yield
      end
    end

    def enqueue(event)
      log(event) do
        payload = event.payload
        data = extract_event(event, payload)
        before_format(data, payload)
      end
    end

    def enqueue_at(event)
      log(event) do
        payload = event.payload
        data = extract_event(event, payload)
        before_format(data, payload)
      end
    end

    def perform(event)
      log(event) do
        payload = event.payload
        data = extract_event(event, payload)
        before_format(data, payload)
      end
    end

    def logger
      Lograge.logger.presence || super
    end

    private

    def log(event)
      return if Lograge.ignore?(event)

      data = yield
      formatted_message = Lograge.formatter.call(data)
      logger.send(Lograge.log_level, formatted_message)
    end

    def extract_event(event, payload = event.payload)
      initial_data(payload).tap do |data|
        data.merge!(extract_action(event))
        data.merge!(extract_duration(event))
        data.merge!(extract_error(payload))
        data.merge!(extract_schedule(payload))
        data.merge!(custom_options(event))
      end
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

    EMPTY_DATA = {}.freeze
    private_constant :EMPTY_DATA

    def extract_error(payload)
      exception, message = payload.fetch(:exception) { return EMPTY_DATA }

      {
        exception: exception,
        error: "#{exception}: #{message}"
      }
    end

    def extract_schedule(payload)
      scheduled_at = payload.fetch(:job).scheduled_at or return EMPTY_DATA

      { scheduled_at: Time.at(scheduled_at).utc }
    end

    def extract_action(event)
      { action: event.name.match(/^([^\.]+)/) }
    end

    def extract_duration(event)
      duration = event.duration or return EMPTY_DATA
      { duration: duration.round(2) }
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

    def before_format(data, payload)
      Lograge.before_format(data, payload)
    end

    def custom_options(event)
      Lograge.custom_options(event) || {}
    end
  end
end
