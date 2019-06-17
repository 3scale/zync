# frozen_string_literal: true
require 'test_helper'

class RESTAdapterTest < ActiveSupport::TestCase
  class_attribute :subject, default: RESTAdapter

  test 'oidc discovery' do
    stub_request(:get, "https://example.com/.well-known/openid-configuration").
      to_return(status: 404, body: '', headers: {})

    assert_nil subject.new('https://example.com').authentication
  end
end
