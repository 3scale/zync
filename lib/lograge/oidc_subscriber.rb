# frozen_string_literal: true

module Lograge
  class OIDCSubscriber < ActiveSupport::LogSubscriber
    def create_client(event)
      log(event) do
        payload = event.payload
        data = extract_client(event, payload)
        before_format(data, payload)
      end
    end

    def update_client(event)
      log(event) do
        payload = event.payload
        data = extract_client(event, payload)
        before_format(data, payload)
      end
    end

    def remove_client(event)
      log(event) do
        payload = event.payload
        data = extract_client(event, payload)
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

    def extract_client(event, payload = event.payload)
      initial_data(payload).tap do |data|
        data.merge!(extract_action(event))
        data.merge!(extract_duration(event))
        data.merge!(extract_error(payload))
        data.merge!(custom_options(event))
      end
    end

    def initial_data(payload)
      client = payload.fetch(:client)

      {
        adapter: extract_adapter(payload),
        client_id: client.id,
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

    def before_format(data, payload)
      Lograge.before_format(data, payload)
    end

    def custom_options(event)
      Lograge.custom_options(event) || {}
    end
  end
end
