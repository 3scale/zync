# frozen_string_literal: true
# Update Integration with latest changes to the model.
# Load latest Entry and push it through the Integration.

class ProcessIntegrationEntryJob < ApplicationJob
  include JobWithTimestamp
  queue_as :default

  def perform(integration, model, service: DiscoverIntegrationService.call(integration))
    IntegrationState.acquire_lock(model, integration) do |state|
      entry = Entry.last_for_model!(model)

      state.update_attributes(started_at: timestamp, entry: entry)

      success = service.call(entry)

      state.update_attributes(success: success, finished_at: timestamp)
    end
  end
end
