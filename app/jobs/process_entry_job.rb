# frozen_string_literal: true

# Process each Entry after it is created.
# So schedule Integration jobs to perform the integration work.

class ProcessEntryJob < ApplicationJob
  queue_as :default

  class_attribute :proxy_integration_services

  def perform(entry)
    model_integrations_for(entry).each do |integration, model|
      ProcessIntegrationEntryJob.perform_later(integration, model)
    end
  end

  def self.model_integrations_for(entry)
    self.ensure_integrations_for(entry)

    model = entry.model
    integrations = Integration.for_model(model)
    integrations.each.with_object(model)
  end

  def self.ensure_integrations_for(entry)
    case entry.model.record
    when Proxy
      proxy_integration_services.map { |integration| integration.new(entry) }.each(&:call)
    when Provider
      CreateK8SIntegration.new(entry).call
    end
  end

  protected

  delegate :model_integrations_for, to: :class

  class ModelIntegration
    attr_reader :model, :data, :entry

    def initialize(entry)
      @entry = entry
      @model = Model.find_by!(record: entry.model.record)
      @data = entry.data || {}.freeze
    end

    def integrations
      ::Integration.where(tenant: tenant, model: model)
    end

    def call
      raise NoMethodError, __method__
    end

    protected

    delegate :transaction, to: :model
    delegate :tenant, to: :entry
  end

  class ProxyIntegration
    attr_reader :service, :data, :entry

    def initialize(entry)
      @entry = entry
      @service = Model.find_by!(record: proxy.record.service)
      @data = entry.data || {}.freeze
    end

    def call
      raise NoMethodError, __method__
    end

    def model
      raise NoMethodError, __method__
    end

    def integrations
      ::Integration.where(tenant: tenant, model: service)
    end

    protected

    delegate :transaction, to: :model
    delegate :tenant, to: :entry

    def proxy
      entry.model
    end
  end

  class CreateK8SIntegration < ModelIntegration
    class_attribute :integration_type, default: Integration::Kubernetes

    class_attribute :enabled, default: Rails.application.config.x.openshift.enabled

    def call
      return unless enabled?

      transaction do
        integration = integrations.create_or_find_by!(type: integration_type.to_s)
        integration.update(state: Integration.states.fetch(:active))

        ProcessIntegrationEntryJob.perform_later(integration, model)
      end
    end
  end

  # Wrapper for creating Keycloak/Generic Adapter when Proxy is created
  class CreateOIDCProxyIntegration < ProxyIntegration
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

    # Unknown oidc_issuer_type in the entry.
    class UnknownOIDCIssuerTypeError < StandardError; end

    def find_integration
      model
        .create_with(endpoint: endpoint)
        .create_or_find_by!(integrations.where_values_hash)
    end
  end

  self.proxy_integration_services = [
    CreateOIDCProxyIntegration,
    CreateK8SIntegration
  ].freeze
end
