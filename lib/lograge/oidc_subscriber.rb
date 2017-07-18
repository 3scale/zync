# frozen_string_literal: true

require 'lograge/subscriber_base'

module Lograge
  # Log Subscriber for OIDC integrations. Consumes Client create/update/remove events.

  class OIDCSubscriber < ActiveSupport::LogSubscriber
    include Lograge::SubscriberBase

    log_event :create_client
    log_event :update_client
    log_event :remove_client

    protected

    def initial_data(payload)
      client = payload.fetch(:client)

      {
        adapter: extract_adapter(payload),
        client_id: client.id,
      }
    end

    def extract_adapter(payload)
      payload.fetch(:adapter).class.name
    end
  end
end
