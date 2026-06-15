# frozen_string_literal: true

if ENV.key?('CI')
  require 'simplecov'
  require 'codecov'

  SimpleCov.start('rails') do
    formatter SimpleCov::Formatter::Codecov
  end
end

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
  def assert_not_outstanding_requests
    WebMock::StubRegistry.instance.request_stubs.each do |stub|
      assert_request_requested(stub, at_least_times: 1)
    end
  end

  setup do
    Que.connection = ActiveRecord # checkout new connection, using transaction
  end
end
