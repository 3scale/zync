# Keeps state of each Integration for each Model
# Also is used as a Lock.

class IntegrationState < ApplicationRecord
  belongs_to :model
  belongs_to :entry, required: false
  belongs_to :integration

  def self.acquire_lock(model, integration)
    transaction do
      state = lock.find_or_create_by!(model: model, integration: integration)

      yield state
    end
  end
end
