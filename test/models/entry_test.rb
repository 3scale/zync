# frozen_string_literal: true
require 'test_helper'

class EntryTest < ActiveSupport::TestCase
  test 'last_for_model!' do
    assert_equal entries(:application), Entry.last_for_model!(models(:application))
    assert_equal entries(:service), Entry.last_for_model!(models(:service))
  end

  test 'data with indifferent access' do
    proxy = entries(:proxy)

    assert_equal proxy.data.fetch('oidc_issuer_endpoint'), proxy.data[:oidc_issuer_endpoint]
  end
end
