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
      when Proxy then CreateProxyIntegration.new(entry).call
      end

      Integration.for_model(model)
    end


    integrations.each.with_object(model)
  end

  # Wrapper for creating KeycloakAdapter when Proxy is created
  CreateProxyIntegration = Struct.new(:entry) do
    attr_reader :service, :data

    def initialize(*)
      super
      @service = Model.find_by!(record: proxy.record.service)
      @data = entry.data || {}.freeze
    end

    def endpoint
      data[:oidc_issuer_endpoint]
    end

    def type
      data[:oidc_issuer_type]
    end

    def valid?
      endpoint
    end

    def call
      unless valid?
        service.logger.info "Not creating integration for #{data}"
        return cleanup
      end

      transaction do
        cleanup

        integration = find_integration
        integration.update(endpoint: endpoint, type: model, state: model.states.fetch(:active))

        ProcessIntegrationEntryJob.perform_later(integration, proxy)
        ProcessIntegrationEntryJob.perform_later(integration, service)
      end
    end

    delegate :transaction, to: :model
    delegate :tenant, to: :entry

    def cleanup
      integrations.update_all(state: Integration.states.fetch(:disabled))
    end

    def model
      case type
      when 'rest'
        ::Integration::REST
      when 'keycloak', nil
        ::Integration::Keycloak
      else raise UnknownOIDCIssuerTypeError, type
      end
    end

    def integrations
      ::Integration.where(tenant: tenant, model: service)
    end

    # Unknown oidc_issuer_type in the entry.
    class UnknownOIDCIssuerTypeError < StandardError; end

    def find_integration
      model
          .create_with(endpoint: endpoint)
          .find_or_create_by!(integrations.where_values_hash)
    end

    def proxy
      entry.model
    end
  end
end
