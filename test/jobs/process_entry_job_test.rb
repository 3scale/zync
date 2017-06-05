require 'test_helper'

class ProcessEntryJobTest < ActiveJob::TestCase
  test 'perform' do
    ProcessEntryJob.perform_now(entries(:one))
  end
end
