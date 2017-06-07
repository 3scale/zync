# frozen_string_literal: true
require 'test_helper'

class DiscoverIntegrationServiceTest < ActiveSupport::TestCase
  def setup
    @service = DiscoverIntegrationService.new
  end

  def test_call
    assert_kind_of Integration::EchoService, @service.call('foo')
  end
end
