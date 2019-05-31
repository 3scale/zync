# frozen_string_literal: true

require 'active_support/concern'

module Lograge

  # Provides base for various log subscribers.
  # It expects you to override `initial_data` method to return a Hash.
  # Another expected change is overriding `merge_data` and mutating data parameter.

  module SubscriberBase
    extend ActiveSupport::Concern

    class_methods do
      def log_event(name)
        alias_method name, :log_event
      end
    end

    def log_event(event)
      log(event) do
        payload = event.payload
        data = extract_data(event, payload)
        before_format(data, payload)
      end
    end

    def logger
      Lograge.logger.presence || super
    end

    protected

    def log(event)
      return if Lograge.ignore?(event)

      data = yield
      formatted_message = Lograge.formatter.call(data)
      logger.send(Lograge.log_level, formatted_message)
    end

    def extract_data(event, payload = event.payload)
      initial_data(payload).tap do |data|
        merge_data(data, event, payload)
      end
    end

    def merge_data(data, event, payload)
      data.merge!(extract_action(event))
      data.merge!(extract_duration(event))
      data.merge!(extract_error(payload))
      data.merge!(custom_options(event))
    end

    def initial_data(_)
      raise NoMethodError, "#{__method__} needs to define initial data"
    end

    EMPTY_DATA = {}.freeze
    private_constant :EMPTY_DATA

    def extract_error(payload)
      error_class, message = payload.fetch(:exception) { return EMPTY_DATA }
      exception = payload[:exception_object]

      {
        exception: error_class,
        error: "#{error_class}: #{message}",
        metadata: exception.try(:bugsnag_meta_data)
      }
    end

    def extract_action(event)
      { action: event.name.match(/^([^\.]+)/) }
    end

    def extract_duration(event)
      duration = event.duration or return EMPTY_DATA
      { duration: duration.round(2) }
    end

    def before_format(data, payload)
      Lograge.before_format(data, payload)
    end

    def custom_options(event)
      Lograge.custom_options(event) || {}
    end
  end
end
