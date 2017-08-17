# frozen_string_literal: true
# Update Integration with latest changes to the model.
# Load latest Entry and push it through the Integration.

class ProcessIntegrationEntryJob < ApplicationJob
  queue_as :default

  delegate :instrument, to: 'ActiveSupport::Notifications'

  def perform(integration, model, service: DiscoverIntegrationService.call(integration))
    return unless service

    result = invoke(model, integration, service) do |invocation|
      payload = build_payload(model, integration, invocation)

      call(payload, &invocation)
    end

    result.value!
  end

  # Wrapper for what is going to be invoked.
  Invocation = Struct.new(:service, :entry, :state) do
    include JobWithTimestamp

    def call(_payload)
      start

      service.call(entry)

      finish(success: true)
    rescue
      finish(success: false)
      raise
    end

    def finish(success: )
      state.update_attributes(success: success, finished_at: timestamp)
    end

    def start
      state.update_attributes(started_at: timestamp, entry: entry, success: nil)
    end

    def to_proc
      method(:call).to_proc
    end

    def service_name
      service.class.name
    end

    # @!method entry_data
    delegate :data, to: :entry, prefix: true
  end

  # Result type of the invocation used to unwrap the error that might have occurred.
  Result = Struct.new(:success, :value, :reason) do
    def value!
      value
    ensure
      raise reason unless success
    end
  end

  def invoke(model, integration, service)
    IntegrationState.acquire_lock(model, integration) do |state|
      entry = Entry.last_for_model!(model)
      invocation = Invocation.new(service, entry, state)

      return yield invocation, state
    end
  end

  def call(payload, &block)
    value = instrument('perform.process_integration_entry', payload, &block)

    Result.new(true, value)
  rescue => exception
    Result.new(false, value, exception)
  end

  def build_payload(model, integration, invocation)
    {
        entry_data: invocation.entry_data, integration: integration, model: model,
        service: invocation.service_name, record: model.record
    }
  end

  # Instrumentation of processing the integration entry to publish MessageBus events.
  class LogSubscriber < ActiveSupport::LogSubscriber
    def start(name, id, payload)
      super

      event = event_stack.last
      method = name.split('.').first

      try("start_#{method}", event)

      event
    end

    def start_perform(_event)
      # TODO: deliver message that event started processing
    end

    def perform(event)
      payload = event.payload
      tenant, options = extract_tenant(payload)
      message_bus = build_message_bus(tenant)
      channel = channel_for(payload)

      message_bus.publish channel, transform_payload(payload), options
    end

    protected

    def channel_for(payload)
      record = payload.fetch(:record) { payload.fetch(:model).record }

      "/integration/#{record.to_gid_param}"
    end

    def transform_payload(payload)
      message_payload = payload.transform_values { |object| object.try(:to_gid) || object }
      message_payload[:success] = !payload.key?(:exception)
      message_payload
    end

    def extract_tenant(payload)
      tenant = payload.fetch(:model).tenant

      [ tenant, { user_ids: [ tenant.to_gid_param ] } ]
    end


    def build_message_bus(tenant)
      MessageBus::Instance.new.tap do |message_bus|
        message_bus.config.merge!(MessageBus.config)
        message_bus.site_id_lookup(&tenant.method(:to_gid_param))
      end
    end
  end

  LogSubscriber.attach_to(:process_integration_entry)
end
