class ProcessIntegrationEntryJob < ApplicationJob
  queue_as :default

  def perform(integration, model)
    zone = Time.zone

    IntegrationState.transaction do
      state = IntegrationState.lock
                .find_or_create_by!(model: model, integration: integration)

      entry = Entry.last!
      state.update_attributes(started_at: zone.now, entry: entry)

      # TODO: call the integration

      state.update_attributes(success: true, finished_at: true)
    end
  end
end
