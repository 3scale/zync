# frozen_string_literal: true

namespace :boot do
  desc "Return failure in case database is not ready"
  task db: :environment do
    spec = ActiveRecord::Base.connection_db_config.configuration_hash
    url = URI::Generic.build(scheme: spec[:adapter], host: spec[:host], path: "/#{spec[:database]}", port: spec[:port])
    begin
      ApplicationRecord.retrieve_connection
      puts "connected to #{url}"
    rescue => error
      warn "failed to connect to: #{url}", error
      exit ApplicationRecord.connected?
    end
  end
end
