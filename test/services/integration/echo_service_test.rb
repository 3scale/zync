# frozen_string_literal: true
require 'test_helper'

class Integration::EchoServiceTest < ActiveSupport::TestCase
  def setup
    @service = Integration::EchoService.new(integrations(:one))
  end

  def test_call
    assert @service.call(entries(:application))
  end
end
