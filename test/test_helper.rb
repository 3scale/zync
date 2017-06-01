require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

if ENV.key?('CI')
  require 'minitest/reporters/junit_reporter'
  Minitest.reporter << Minitest::Reporters::JUnitReporter.new
end

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end
