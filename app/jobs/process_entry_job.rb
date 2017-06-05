class ProcessEntryJob < ApplicationJob
  queue_as :default

  def perform(entry)
    integrations = entry.tenant.integrations


    # Do something later
  end
end
