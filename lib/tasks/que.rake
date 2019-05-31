# frozen_string_literal: true

desc 'Start que worker'
task que: :environment do |_, args|
  exec("que ./config/environment.rb que/prometheus #{args.extras.join}")
end
