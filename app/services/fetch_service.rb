# frozen_string_literal: true

# Fetches Model information from upstream and returns the Entity.

class FetchService
  def initialize
    freeze
  end

  class << self
    delegate :call, to: :new
  end

  # Returned when unknown model is passed in.
  class UnsupportedModel < StandardError; end

  # @return [ThreeScale::API::Client]
  def build_client(tenant)
    http_client = ThreeScale::API::InstrumentedHttpClient.new(endpoint: tenant.endpoint,
                                                              provider_key: tenant.access_token)
    ThreeScale::API::Client.new(http_client)
  end

  def call(model)
    case record = model.record
    when Service
      fetch_service(model)
    when Application
      fetch_application(model)
    when Client
      fetch_client(model)
    when Proxy
      fetch_proxy(model)
    when Provider
      fetch_provider(model)
    else
      raise UnsupportedModel, "unsupported model #{record.class}"
    end
  end

  def fetch_provider(model)
    fetch_entry(model) do |client|
      client.show_provider
    end
  end

  def fetch_service(model)
    build_entry(model)
  end

  def fetch_proxy(model)
    fetch_entry(model) do |client|
      client.show_proxy(model.record.service_id)
    end
  end

  def fetch_application(model)
    fetch_entry(model) do |client|
      client.show_application(model.record_id)
    end
  end

  def fetch_client(model)
    fetch_entry(model) do |client|
      client.find_application(application_id: model.record.client_id)
    end
  end

  def fetch_entry(model)
    client = build_client(model.tenant)

    data = begin
      yield client
           rescue RuntimeError => e
             Rails.logger.error(e)
             nil
    end

    build_entry(model, data: data)
  end

  def build_entry(model, **attributes)
    Entry.for_model(model).tap do |entry|
      entry.assign_attributes attributes
      Rails.logger.debug "[FetchService] got Entry (#{model.record.class}): #{entry.attributes.compact}"
    end
  end
end
