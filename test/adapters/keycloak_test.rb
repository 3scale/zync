# frozen_string_literal: true
require 'test_helper'

class KeycloakTest < ActiveSupport::TestCase
  test 'new' do
    assert Keycloak.new('http://id:secret@lvh.me:3000/auth/realm/name')
  end

  test 'endpoint' do
    keycloak = Keycloak.new('http://id:secret@lvh.me:3000/auth/realm/name')

    assert_kind_of URI, keycloak.endpoint
  end

  test 'endpoint normalization' do
    uri = URI('http://lvh.me:3000/auth/realm/name/')

    assert_equal uri,
                 Keycloak.new('http://id:secret@lvh.me:3000/auth/realm/name').endpoint

    assert_equal uri,
                 Keycloak.new('http://id:secret@lvh.me:3000/auth/realm/name/').endpoint
  end
end
