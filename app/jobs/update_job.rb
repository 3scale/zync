# Uses FetchService to get Entity and persist it in database.
# Maintains UpdateState and can be only one running at a time by using a lock on model.

class UpdateJob < ApplicationJob
  queue_as :default

  def perform(model)
    zone = Time.zone

    UpdateState.transaction do
      state = UpdateState.lock.find_or_create_by!(model: model)

      # this is not going to be visible outside the transaction, does it matter?
      # what matters is that it could be rolled back
      state.update_attributes(started_at: zone.now)

      # TODO: fetch data from the API

      state.update_attributes(success: true, finished_at: zone.now)
    end
  end
end
