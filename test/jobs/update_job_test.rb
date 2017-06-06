require 'test_helper'

class UpdateJobTest < ActiveJob::TestCase
  test 'create update object' do
    model = Model.create!(tenant: tenants(:two), record: applications(:two))

    FetchService.stub :call, Entry.new do
      assert_difference UpdateState.method(:count) do
        UpdateJob.perform_now(model)
        UpdateJob.perform_now(model)
      end
    end
  end

  test 'creates entry' do
    model = Model.create!(tenant: tenants(:two), record: applications(:two))

    FetchService.stub :call,Entry.method(:for_model) do
      assert_difference Entry.method(:count), +2 do
        UpdateJob.perform_now(model)
        UpdateJob.perform_now(model)
      end
    end
  end
end
