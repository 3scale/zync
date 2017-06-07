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
    integration = integrations(:two)
    job = ProcessIntegrationEntryJob.new(integration, models(:service), service: service)

    service.expect(:call, true) do |int, entry|
      assert_equal integration, int
      assert_equal entries(:service), entry
    end

    assert job.perform_now

    assert_mock service
  end
end
