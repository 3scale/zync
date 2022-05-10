# frozen_string_literal: true
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

  test 'relation' do
    application = UpdateJob.new(models(:application))
    client = UpdateJob.new(models(:client))

    refute_equal application.relation.to_sql, client.relation.to_sql

    adapter = ActiveJob::QueueAdapters::QueAdapter.new

    assert_difference application.relation.method(:count), 2 do
      adapter.enqueue(application)
      adapter.enqueue(application)

      assert_difference client.relation.method(:count), 2 do
        adapter.enqueue(client)
        adapter.enqueue(client)
      end
    end
  end

  test 'perform later' do
    adapter = ActiveJob::QueueAdapters::QueAdapter.new
    job = UpdateJob.new(models(:application))

    adapter.enqueue(job)

    assert_difference job.relation.method(:count), -1 do
      ApplicationJob.perform_later(job) # this is not using the same adapter, so it actually just removes previous one
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
