# frozen_string_literal: true

require 'lograge/subscriber_base'

module Lograge
  # Log Subscriber for OIDC integrations. Consumes Client create/update/remove events.

  class NetHttpSubscriber < ActiveSupport::LogSubscriber
    include Lograge::SubscriberBase

    log_event :connect
    log_event :transport_request
    log_event :ssl_socket_connect
    log_event :exec
    log_event :reading_body
    log_event :begin_transport
    log_event :end_transport
    log_event :read_new

    protected

    def initial_data(payload)

      data = extract_payload(payload.fetch(:adapter))

      data
          .merge(extract_payload(payload[:request]))
          .merge(extract_payload(payload[:response]))
    end

    def extract_payload(adapter)
      case adapter
        when Net::HTTP
          {
              adapter: 'Net::HTTP',
              address: adapter.address, port: adapter.port,
              ssl: adapter.use_ssl?, proxy: adapter.proxy?
          }
        when Net::HTTPGenericRequest
          {
              adapter: 'Net::HTTP',
              uri: adapter.uri, path: adapter.path

          }
        when Net::HTTPResponse
          {
              adapter: 'Net::HTTP',
              uri: adapter.uri, message: adapter.message, code: adapter.code

          }
        when nil then {}
        else
          raise "can't extract data from #{adapter.class}"
      end
    end
  end
end
