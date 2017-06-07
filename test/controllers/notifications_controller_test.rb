# frozen_string_literal: true
require 'test_helper'

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  test 'update' do
    put notification_url(format: :json), params: { notification: { type: 'Application', tenant_id: tenants(:one).id } }
    assert_response :success
  end

end
