# frozen_string_literal: true
require 'test_helper'

class StatusesControllerTest < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end
  test 'show' do
    get status_path
    assert_response :success
  end
end
