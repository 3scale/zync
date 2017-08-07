# frozen_string_literal: true
require 'test_helper'

class ProcessIntegrationEntryJobTest < ActiveJob::TestCase

  test 'perform' do
    integration = integrations(:one)
    application = models(:application)

    assert_difference IntegrationState.method(:count) do
      ProcessIntegrationEntryJob.perform_now(integration, application)
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
end
