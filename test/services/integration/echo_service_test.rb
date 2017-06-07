# frozen_string_literal: true
require 'test_helper'

class Integration::EchoServiceTest < ActiveSupport::TestCase
  def setup
    @service = Integration::EchoService.new
  end

  def test_call
    assert @service.call(integrations(:one), entries(:application))
  end
end
