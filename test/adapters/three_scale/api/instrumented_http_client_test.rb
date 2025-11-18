# frozen_string_literal: true
require 'test_helper'

class ThreeScale::API::InstrumentedHttpClientTest < ActiveSupport::TestCase

  test 'new' do
    uri = 'http://system.local'
    http_client = ThreeScale::API::InstrumentedHttpClient.new(endpoint: uri, provider_key: 'provider-key')

    Rails.application.secrets.stub(:authentication, {token: 'zync-token'}) do
      stub_request(:any, 'http://system.local/all.json').to_return(status: 200, body: "", headers: {})
      http_client.put('/all')
      assert_requested(:put, "http://system.local/all.json", headers: {'X-Zync-Token' => 'zync-token'})
    end
  end

end
