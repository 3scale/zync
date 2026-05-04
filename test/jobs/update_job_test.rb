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

  test 'retries on Errno::ECONNREFUSED' do
    model = Model.create!(tenant: tenants(:two), record: applications(:two))
    call_count = 0
    
    # Stub FetchService.call to raise Errno::ECONNREFUSED on first call, succeed on second
    FetchService.stub :call, lambda { |_|
      call_count += 1
      if call_count == 1
        raise Errno::ECONNREFUSED, 'Connection refused'
      else
        Entry.new
      end
    } do

      perform_enqueued_jobs do
        UpdateJob.perform_later(model)
      end
      
      # Verify that the job was called twice (initial attempt + 1 retry)
      assert_equal 2, call_count, 'UpdateJob should retry once after Errno::ECONNREFUSED'
    end
  end
end
