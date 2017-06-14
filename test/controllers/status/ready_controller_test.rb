# frozen_string_literal: true
require 'test_helper'

class Status::ReadyControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get status_ready_url
    assert_response :success
  end

end
