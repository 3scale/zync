# frozen_string_literal: true

task que: 'que:exec'

namespace :que do
  desc 'Start que worker'
  task exec: :environment do |_, args|
    db_config = ActiveRecord::Base.connection_db_config.configuration_hash

    # Build base URL
    connection_url = "#{db_config[:adapter]}://"
    connection_url += "#{db_config[:username]}" if db_config[:username]
    connection_url += ":#{db_config[:password]}" if db_config[:password]
    connection_url += "@" if db_config[:username] || db_config[:password]
    connection_url += db_config[:host] || 'localhost'
    connection_url += ":#{db_config[:port]}" if db_config[:port]
    connection_url += "/#{db_config[:database]}"

    # Add SSL parameters as query string
    ssl_params = []
    ssl_params << "sslmode=#{db_config[:sslmode]}" if db_config[:sslmode]
    ssl_params << "sslrootcert=#{db_config[:sslrootcert]}" if db_config[:sslrootcert]
    ssl_params << "sslcert=#{db_config[:sslcert]}" if db_config[:sslcert]
    ssl_params << "sslkey=#{db_config[:sslkey]}" if db_config[:sslkey]
    connection_url += "?#{ssl_params.join('&')}" if ssl_params.any?

    exec("que --connection-url '#{connection_url}' ./config/environment.rb que/prometheus #{args.extras.join}")
  end

  desc 'Reschedule all jobs to be executed now'
  task reschedule: :environment do
    require 'que/active_record/model'

    Que::ActiveRecord::Model.update_all(run_at: Time.now)
  end

  desc 'Force updating all models'
  task force_update: :environment do
    Model.find_each(&UpdateJob.method(:perform_later))
  end
end

