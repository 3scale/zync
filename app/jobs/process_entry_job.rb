class ProcessEntryJob < ApplicationJob
  queue_as :default

  def perform(entry)
    integrations = entry.tenant.integrations
    model = entry.model

    integrations.each do |integration|
      ProcessIntegrationEntryJob.perform_later(integration, model)
    end
  end
end
