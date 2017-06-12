# frozen_string_literal: true
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'minitest/mock'
require 'webmock/minitest'

if ENV.key?('CI')
  Minitest.extensions << 'ci'
  Minitest.class_eval do
    def self.plugin_ci_init(_)
      require 'minitest/reporters/junit_reporter'
      reporter << Minitest::Reporters::JUnitReporter.new
    end
  end
end

if ENV.key?('PRY_RESCUE')
  require 'pry-rescue/minitest'
end

Que.start!

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end
