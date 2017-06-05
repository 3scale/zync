require 'test_helper'

class ProcessIntegrationEntryJobTest < ActiveJob::TestCase

  test 'perform' do
    integration = integrations(:one)
    application = models(:application)

    assert_difference IntegrationState.method(:count) do
      ProcessIntegrationEntryJob.perform_now(integration, application)
    end
  end
end
