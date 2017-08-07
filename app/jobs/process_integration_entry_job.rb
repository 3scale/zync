# frozen_string_literal: true
# Update Integration with latest changes to the model.
# Load latest Entry and push it through the Integration.

class ProcessIntegrationEntryJob < ApplicationJob
  include JobWithTimestamp
  queue_as :default

  delegate :instrument, to: 'ActiveSupport::Notifications'

  def perform(integration, model, service: DiscoverIntegrationService.call(integration))
    failure = nil
    success = nil


    IntegrationState.acquire_lock(model, integration) do |state|
      entry = Entry.last_for_model!(model)

      payload = {
        entry_data: entry.data, integration: integration, model: model,
        service: service.class.name, record: model.record
      }

      state.update_attributes(started_at: timestamp, entry: entry)

      begin
        success = instrument('perform.process_integration_entry', payload) do
          service.call(entry) || true
        end
      rescue => error
        success = false
        failure = error
      ensure
        state.update_attributes(success: success, finished_at: timestamp)
      end
    end

    raise failure if failure

    success
  end

  class LogSubscriber < ActiveSupport::LogSubscriber
    def start(name, id, payload)
      super

      event = event_stack.last
      method = name.split('.').first

      try("start_#{method}", event)
    end

    def start_perform(event)
      # TODO: deliver message that event started processing
    end

    def perform(event)
      payload = event.payload
      tenant = payload.fetch(:model).tenant
      message_bus = build_message_bus(tenant)

      message_payload = payload.transform_values { |object| object.try(:to_gid) || object }
      message_options = { user_ids: [ tenant.to_gid_param ] }

      message_payload.merge!(success: !payload.key?(:exception))

      message_bus.publish '/integration', message_payload, message_options
    end

    protected

    def build_message_bus(tenant)
      MessageBus::Instance.new.tap do |message_bus|
        message_bus.config.merge!(MessageBus.config)
        message_bus.site_id_lookup(&tenant.method(:to_gid_param))
      end
    end
  end

  LogSubscriber.attach_to(:process_integration_entry)
end
