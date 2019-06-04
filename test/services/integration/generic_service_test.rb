# frozen_string_literal: true

require 'test_helper'

class Integration::GenericServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
  end

  def test_new
    assert Integration::GenericService.new(integrations(:generic))
  end

  test 'creating client' do
    Client.delete_all

    assert_difference Client.method(:count) do
      subject.call(entries(:application))
    end
  end

  test 'using existing client' do
    assert_no_difference Client.method(:count) do
      subject.call(entries(:application))
    end
  end

  test 'schedules UpdateJob when creating Client' do
    entry = entries(:application)
    model = subject.call(entry)

    assert_enqueued_with job: UpdateJob,
                         args: [ model ] do
      subject.call(entry)
    end
  end

  test 'update client' do
    entry = entries(:client)

    adapter = MiniTest::Mock.new
    adapter.expect(:update_client, true, [ GenericAdapter::Client ])

    subject.stub(:adapter, adapter) do |service|
      service.call(entry)
    end

    assert_mock adapter
  end

  test 'delete client' do
    entry = entries(:client)
    entry.data = entry.data.except(:enabled)

    adapter = MiniTest::Mock.new
    adapter.expect(:delete_client, true, [ GenericAdapter::Client ])

    subject.stub(:adapter, adapter) do |service|
      service.call(entry)
    end

    assert_mock adapter
  end

  test 'client auth flows attributes' do
    entry = entries(:client)

    stub_request(:put, 'http://example.com/generic/api/clients/two_id').
        with(
            body: {
                client_id: 'two_id',
                client_secret: 'two_secret',
                client_name: 'client name',
                redirect_uris: %w[http://example.com],
                grant_types: %w[authorization_code implicit client_credentials password]
            }.to_json, headers: { 'Content-Type'=>'application/json' }).
        to_return(status: 200)

    subject.tap do |service|
      service.adapter.authentication = 'foobar'
      service.call(entry)
    end
  end

  protected

  def subject
    Integration::GenericService.new(integrations(:generic))
  end
end
