# Keeps history of Model Updates.

class Entry < ApplicationRecord
  belongs_to :tenant
  belongs_to :model

  after_create_commit :process_entry

  def process_entry
    ProcessEntryJob.perform_later(self)
  end

  def self.for_model(model)
    new(model: model, tenant: model.try!(:tenant))
  end
end
