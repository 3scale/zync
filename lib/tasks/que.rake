# frozen_string_literal: true

task que: 'que:exec'

namespace :que do
  desc 'Start que worker'
  task exec: :environment do |_, args|
    exec("que ./config/environment.rb que/prometheus #{args.extras.join}")
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
