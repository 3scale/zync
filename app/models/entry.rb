# frozen_string_literal: true
# Keeps history of Model Updates.

class Entry < ApplicationRecord
  belongs_to :tenant
  belongs_to :model

  delegate :record, to: :model

  after_create_commit :process_entry

  scope :with_data, -> { where.not(data: nil) }

  def previous_data
    model.entries.with_data.last!.data
  end

  def data
    super&.with_indifferent_access
  end

  def last_known_data
    (data || previous_data || {})
  end

  def process_entry
    ProcessEntryJob.perform_later(self)
  end

  def self.for_model(model)
    new(model: model, tenant: model.try!(:tenant))
  end

  def self.last_for_model!(model)
    where(model: model).last!
  end
end
