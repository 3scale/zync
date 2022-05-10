# frozen_string_literal: true
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

  test 'call with Provider' do
    stub_request(:get, "#{tenants(:two).endpoint}/admin/api/provider.json").
      to_return(status: 200, body: '{}', headers: {})

    assert_kind_of Entry, @service.call(models(:provider))
  end

  test 'call with Client' do
    stub_request(:get, "#{tenants(:two).endpoint}/admin/api/applications/find.json?app_id=two").
      to_return(status: 200, body: '{}', headers: {})

    assert_kind_of Entry, @service.call(models(:client))
  end

  test 'call with Proxy' do
    stub_request(:get, "https://two.example.com/admin/api/services/298486374/proxy.json").
      to_return(status: 200, body: '{}', headers: {})

    assert_kind_of Entry, @service.call(models(:proxy))
  end

  test 'call returns entry that can be saved' do
    @service.call(models(:service)).save!
  end
end
