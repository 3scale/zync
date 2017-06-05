class ProcessIntegrationEntryJob < ApplicationJob
  queue_as :default

  def initialize(*)
    super
    @discover = DiscoverIntegrationService.new
  end

  attr_reader :discover

  def perform(integration, model)
    zone = Time.zone

    service = discover.call(integration)

    IntegrationState.transaction do
      state = IntegrationState.lock
                .find_or_create_by!(model: model, integration: integration)

      entry = Entry.last!
      state.update_attributes(started_at: zone.now, entry: entry)

      # TODO: call the integration

      service.call(integration, entry)

      state.update_attributes(success: true, finished_at: true)
    end
  end
end
