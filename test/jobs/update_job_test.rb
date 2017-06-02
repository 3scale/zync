require 'test_helper'

class UpdateJobTest < ActiveJob::TestCase
  test 'create update object' do
    model = Model.create!(tenant: tenants(:two), record: applications(:two))

    assert_difference UpdateState.method(:count) do
      UpdateJob.perform_now(model)
      UpdateJob.perform_now(model)
    end
  end
end
