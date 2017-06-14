# frozen_string_literal: true
require 'test_helper'

class StatusServiceTest < ActiveSupport::TestCase
  def setup
  end

  def test_live
    status = StatusService.live
    json = { database: true, ok: true }.to_json
    assert_equal json,status.to_json
  end

  def test_ready
    status = StatusService.ready
    json = { database: true, ok: true }.to_json
    assert_equal json,status.to_json
  end
end
