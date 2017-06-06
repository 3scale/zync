require 'test_helper'

class FetchServiceTest < ActiveSupport::TestCase
  def setup
    @service = FetchService.new
  end

  test 'call with Service' do
    assert_kind_of Entry, @service.call(models(:service))
  end

  test 'call with Application' do
    stub_request(:get, "#{tenants(:one).endpoint}/admin/api/applications/find.json?application_id=980190962").
      to_return(status: 200, body: '{}', headers: {})

    assert_kind_of Entry, @service.call(models(:application))
  end

  test 'call returns entry that can be saved' do
    @service.call(models(:service)).save!
  end
end
