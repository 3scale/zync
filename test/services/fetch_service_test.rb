require 'test_helper'

class FetchServiceTest < ActiveSupport::TestCase
  def setup
    @service = FetchService.new
  end

  test 'call with Service' do
    assert_kind_of Entry, @service.call(models(:service))
  end

  test 'call with Application' do
    assert_kind_of Entry, @service.call(models(:application))
  end

  test 'call returns entry that can be saved' do
    @service.call(models(:service)).save!
  end
end
