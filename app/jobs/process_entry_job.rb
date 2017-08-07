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
        create_keycloak_integration(entry)
      end

      Integration.for_model(model)
    end


    integrations.each.with_object(model)
  end

  def create_keycloak_integration(entry)
    proxy = entry.model
    service = Model.find_by!(record: proxy.record.service)
    endpoint = entry.data.fetch(:oidc_issuer_endpoint)
    keycloak = Integration::Keycloak
                 .create_with(endpoint: endpoint)
                 .find_or_create_by!(tenant: entry.tenant, model: service)
    keycloak.update(endpoint: endpoint)

    ProcessIntegrationEntryJob.perform_later(keycloak, proxy)


    ProcessIntegrationEntryJob.perform_later(keycloak, service)
  end
end
