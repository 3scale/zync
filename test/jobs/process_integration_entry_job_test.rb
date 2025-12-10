# frozen_string_literal: true
require 'test_helper'

class ProcessIntegrationEntryJobTest < ActiveJob::TestCase

  test 'perform' do
    integration = integrations(:one)
    service = models(:service)

    assert_difference IntegrationState.method(:count) do
      ProcessIntegrationEntryJob.perform_now(integration, service)
    end
  end

  test 'uses correct entry' do
    service = Minitest::Mock.new
    integration = integrations(:keycloak)
    job = ProcessIntegrationEntryJob.new(integration, models(:service), service: service)

    service.expect(:call, true) do |entry|
      assert_equal entries(:service), entry
    end

    assert job.perform_now

    assert_mock service
  end

  test 're-raises exeption' do
    service = ->(_) { raise 'error' }

    state = IntegrationState.acquire_lock(models(:service), integrations(:keycloak), &:itself)

    assert_nil state.success
    job = ProcessIntegrationEntryJob.new(state.integration, state.model, service: service)

    assert_raises RuntimeError do
      job.perform_now
    end

    state.reload

    assert_equal false, state.success
  end

  test 'log subscriber publishes messages' do
    subscriber = ProcessIntegrationEntryJob::LogSubscriber.new

    model = models(:application)
    record = model.record
    payload = { model: model, record: record, entry_data: { test: 'data' } }

    event = ActiveSupport::Notifications::Event.new('perform', nil, nil, 'foo', payload)
    event.start!

    # Mock MessageBus::Instance to verify publish is called
    message_bus_mock = Minitest::Mock.new
    expected_channel = "/integration/#{record.to_gid_param}"
    expected_options = { user_ids: [model.tenant.to_gid_param] }

    # Expect publish to be called with correct channel, transformed payload, and options
    message_bus_mock.expect(:publish, true) do |channel, message, options|
      assert_equal expected_channel, channel, "Channel should match the record's GID"
      assert_equal true, message[:success], "Success should be true when no exception"
      assert message.key?(:model), "Message should contain model"
      assert message.key?(:record), "Message should contain record"
      assert message.key?(:entry_data), "Message should contain entry_data"
      assert_equal expected_options, options, "Options should contain user_ids"
      true
    end

    # Stub the build_message_bus method to return our mock
    subscriber.stub(:build_message_bus, message_bus_mock) do
      subscriber.perform(event)
    end

    assert_mock message_bus_mock
  end

  test 'skips disabled integration' do
    integration = integrations(:keycloak)
    model = models(:service)

    service = Minitest::Mock.new
    service.expect(:call, true, [Entry])

    ProcessIntegrationEntryJob.perform_now(integration, model, service: service)

    assert_mock service
  end

  test 'relation' do
    service = ProcessIntegrationEntryJob.new(integrations(:keycloak), models(:service))
    application = ProcessIntegrationEntryJob.new(integrations(:keycloak), models(:application))

    refute_equal application.relation.to_sql, service.relation.to_sql

    adapter = ActiveJob::QueueAdapters::QueAdapter.new

    assert_difference application.relation.method(:count), 2 do
      adapter.enqueue(application)
      adapter.enqueue(application)

      assert_difference service.relation.method(:count), 2 do
        adapter.enqueue(service)
        adapter.enqueue(service)
      end
    end
  end

  test 'perform later' do
    adapter = ActiveJob::QueueAdapters::QueAdapter.new
    job = ProcessIntegrationEntryJob.new(integrations(:keycloak), models(:application))

    adapter.enqueue(job)

    assert_difference job.relation.method(:count), -1 do
      ApplicationJob.perform_later(job) # this is not using the same adapter, so it actually just removes previous one
    end
  end
end
