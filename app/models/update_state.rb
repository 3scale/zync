# frozen_string_literal: true
# Keeps state of each Update for each Model
# Also is used as a Lock.

class UpdateState < ApplicationRecord
  belongs_to :model

  def self.acquire_lock(model)
    transaction do
      state = lock.find_or_create_by!(model: model.lock!)

      yield state
    end
  end
end
