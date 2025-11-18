# frozen_string_literal: true

require 'lograge/subscriber_base'

module Lograge
  # Log Subscriber for OIDC integrations. Consumes Client create/update/remove events.

  class HttpSubscriber < ActiveSupport::LogSubscriber
    include Lograge::SubscriberBase

    log_event :request

    protected

    def initial_data(payload)
      payload.merge(adapter: extract_adapter(payload))
    end

    def extract_adapter(payload)
      payload.fetch(:adapter).class.name
    end
  end
end
