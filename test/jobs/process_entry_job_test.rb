# frozen_string_literal: true
require 'test_helper'

class ProcessEntryJobTest < ActiveJob::TestCase
  test 'perform' do
    entry = entries(:application)

    assert_enqueued_with job: ProcessIntegrationEntryJob,
                         args: [  integrations(:one),  entry.model ] do
      ProcessEntryJob.perform_now(entry)
    end
  end

  test 'model integrations for' do
    job = ProcessEntryJob.new
    proxy = entries(:proxy)

    integrations = job.model_integrations_for(proxy)

    assert_equal 0, integrations.size
  end
end
