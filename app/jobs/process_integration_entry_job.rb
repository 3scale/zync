# frozen_string_literal: true

# Update Integration with latest changes to the model.
# Load latest Entry and push it through the Integration.

class ProcessIntegrationEntryJob < ApplicationJob
  queue_as :default

  self.deduplicate = true

  delegate :instrument, to: 'ActiveSupport::Notifications'

  def perform(integration, model, service: DiscoverIntegrationService.call(integration))
    return unless service

    if integration.try(:disabled?)
      logger.info "#{integration.to_gid} is disabled, skipping"
      return
    end

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
    rescue StandardError
      finish(success: false)
      raise
    end

    def finish(success:)
      state.update(success: success, finished_at: timestamp)
    end

    def start
      state.update(started_at: timestamp, entry: entry, success: nil)
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
  rescue StandardError => e
    Result.new(false, value, e)
  end

  def build_payload(model, integration, invocation)
    {
      entry_data: invocation.entry_data, integration: integration, model: model,
      service: invocation.service_name, record: model.record
    }
  end
end
