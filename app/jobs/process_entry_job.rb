# frozen_string_literal: true
# Process each Entry after it is created.
# So schedule Integration jobs to perform the integration work.

class ProcessEntryJob < ApplicationJob
  queue_as :default

  def perform(entry)
    model_integrations_for(entry).each do |integration, model|
      ProcessIntegrationEntryJob.perform_later(integration, model)
    end
  end

  def model_integrations_for(entry)
    model = entry.model

    integrations = Integration.retry_record_not_unique do
      case model.record
        when Proxy
          CreateKeycloakIntegration.new(entry).call
      end

      Integration.for_model(model)
    end


    integrations.each.with_object(model)
  end

  # Wrapper for creating Keycloak when Proxy is created
  CreateKeycloakIntegration = Struct.new(:entry) do
    attr_reader :service

    def initialize(*)
      super
      @service = Model.find_by!(record: proxy.record.service)
    end

    def endpoint
      entry.data.fetch(:oidc_issuer_endpoint)
    end

    def call
      transaction do
        integration.update(endpoint: endpoint)

        ProcessIntegrationEntryJob.perform_later(integration, proxy)
        ProcessIntegrationEntryJob.perform_later(integration, service)
      end
    end

    delegate :transaction, to: :model
    delegate :tenant, to: :entry

    def model
      ::Integration::Keycloak
    end

    def integration
      model
          .create_with(endpoint: endpoint)
          .find_or_create_by!(tenant: tenant, model: service)
    end

    def proxy
      entry.model
    end
  end
end
