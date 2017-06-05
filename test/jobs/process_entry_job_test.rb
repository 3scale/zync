require 'test_helper'

class ProcessEntryJobTest < ActiveJob::TestCase
  test 'perform' do
    entry = entries(:one)

    assert_enqueued_with job: ProcessIntegrationEntryJob,
                         args: [  integrations(:one),  entry.model ] do
      ProcessEntryJob.perform_now(entry)
    end
  end
end
