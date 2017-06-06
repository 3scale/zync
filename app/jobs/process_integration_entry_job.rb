# Update Integration with latest changes to the model.
# Load latest Entry and push it through the Integration.

class ProcessIntegrationEntryJob < ApplicationJob
  queue_as :default

  def initialize(integration, model, service: nil)
    super(integration, model)
    @service = service || DiscoverIntegrationService.call(integration)
  end

  attr_reader :service

  def perform(integration, model)
    zone = Time.zone

    IntegrationState.transaction do
      state = IntegrationState.lock
                .find_or_create_by!(model: model, integration: integration)

      entry = Entry.last_for_model!(model) # FIXME: this is broken and should find the latest for the model
      state.update_attributes(started_at: zone.now, entry: entry)

      service.call(integration, entry)

      state.update_attributes(success: true, finished_at: true)
    end
  end
end
