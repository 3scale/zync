# frozen_string_literal: true

namespace :boot do
  desc "Return failure in case database is not ready"
  task db: :environment do
    begin
      ApplicationRecord.retrieve_connection
    rescue => error
      warn error
      exit ApplicationRecord.connected?
    end
  end
end
