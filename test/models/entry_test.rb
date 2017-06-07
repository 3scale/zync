# frozen_string_literal: true
require 'test_helper'

class EntryTest < ActiveSupport::TestCase
  test 'last_for_model!' do
    assert_equal entries(:application), Entry.last_for_model!(models(:application))
    assert_equal entries(:service), Entry.last_for_model!(models(:service))
  end
end
