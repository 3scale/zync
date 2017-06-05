class Entry < ApplicationRecord
  belongs_to :tenant
  belongs_to :model

  after_create_commit :process_entry

  def process_entry
    ProcessEntryJob.perform_later(self)
  end
end
