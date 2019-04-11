# frozen_string_literal: true

task que: :environment do |_, args|
  exec("que ./config/environment.rb que/prometheus #{args.extras.join}")
end
