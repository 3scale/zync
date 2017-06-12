# frozen_string_literal: true
require 'test_helper'

class StatusServiceTest < ActiveSupport::TestCase
  def setup
  end

  def test_call
    status = StatusService.call
    json = { database: true, ok: true }.to_json
    assert_equal json,status.to_json
  end
end
