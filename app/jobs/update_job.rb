class UpdateJob < ApplicationJob
  queue_as :default

  def perform(model)
    UpdateState.transaction do
      state = UpdateState.lock.find_or_create_by!(model: model)

      # this is not going to be visible outside the transaction, does it matter?
      # what matters is that it could be rolled back
      state.update_attributes(started_at: Time.zone.now)

      # TODO: fetch data from the API

      state.update_attributes(success: true, finished_at: Time.zone.now)
    end
  end
end
