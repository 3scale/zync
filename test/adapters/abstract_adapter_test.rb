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
end
