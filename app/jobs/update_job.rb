# frozen_string_literal: true
# Uses FetchService to get Entity and persist it in database.
# Maintains UpdateState and can be only one running at a time by using a lock on model.

require 'que/active_record/model'

class UpdateJob < ApplicationJob
  include JobWithTimestamp
  queue_as :default

  retry_on Errno::ECONNREFUSED, wait: :exponentially_longer, attempts: 10
  retry_on Model::LockTimeoutError, wait: :exponentially_longer, attempts: 10

  def initialize(*)
    super
    @fetch = FetchService
  end

  attr_reader :fetch

  def relation
    record = self.class.model
    arguments = serialize.slice('arguments')
    record.where.has {
      args.op('@>', quoted([arguments].to_json))
    }
  end

  def perform(model)
    UpdateState.acquire_lock(model) do |state|
      # this is not going to be visible outside the transaction, does it matter?
      # what matters is that it could be rolled back
      state.update_attributes(started_at: timestamp)

      entry = fetch.call(model)

      state.update_attributes(success: entry.save, finished_at: timestamp)
    end
  end

  def self.model
    Que::ActiveRecord::Model.by_job_class(to_s)
  end

  def self.perform_later(*args)
    model.transaction do
      job = job_or_instantiate(*args)
      job.relation.delete_all
      job.enqueue
    end
  end
end
