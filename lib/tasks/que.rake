# frozen_string_literal: true

require 'que/db_connection_url'

task que: 'que:exec'

namespace :que do
  desc 'Start que worker'
  task exec: :environment do |_, args|
    # Build base URL
    # Workaround for https://github.com/que-rb/que/issues/442
    db_config = ActiveRecord::Base.connection_db_config.configuration_hash
    connection_url = Que::DBConnectionURL.build_connection_url(db_config)

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

