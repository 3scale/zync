# Uses FetchService to get Entity and persist it in database.
# Maintains UpdateState and can be only one running at a time by using a lock on model.

class UpdateJob < ApplicationJob
  include JobWithTimestamp
  queue_as :default

  def initialize(*)
    super
    @fetch = FetchService
  end

  attr_reader :fetch

  def perform(model)
    UpdateState.acquire_lock(model) do |state|
      # this is not going to be visible outside the transaction, does it matter?
      # what matters is that it could be rolled back
      state.update_attributes(started_at: timestamp)

      entry = fetch.call(model)

      state.update_attributes(success: entry.save, finished_at: timestamp)
    end
  end
end
