# frozen_string_literal: true
require 'test_helper'

class AbstractAdapterTest < ActiveSupport::TestCase
  class_attribute :subject, default: AbstractAdapter

  test 'new' do
    assert subject.new('http://id:secret@lvh.me:3000/auth/realm/name')
  end

  test 'endpoint' do
    adapter = subject.new('http://id:secret@lvh.me:3000/auth/realm/name')

    assert_kind_of URI, adapter.endpoint
  end

  test 'endpoint normalization' do
    uri = URI('http://lvh.me:3000/auth/realm/name/')

    assert_equal uri,
                 subject.new('http://id:secret@lvh.me:3000/auth/realm/name').endpoint

    assert_equal uri,
                 subject.new('http://id:secret@lvh.me:3000/auth/realm/name/').endpoint
  end

  test 'http_client' do
    HTTPClient::Util.stub_const(:AddressableEnabled, false) do
      assert_kind_of subject, subject.new('http://id:secret@example.com')
    end
  end

  test 'oidc discovery' do
    stub_request(:get, "https://example.com/.well-known/openid-configuration").
      to_return(status: 404, body: '', headers: {})

    assert_raises AbstractAdapter::OIDC::AuthenticationError do
      assert_nil subject.new('https://example.com').authentication
    end
  end
end
