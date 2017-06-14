# frozen_string_literal: true
require 'test_helper'

class Status::LiveControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get status_live_url
    assert_response :success
  end

end
