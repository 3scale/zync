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

  # @return [ThreeScale::API]
  def build_client(tenant)
    ThreeScale::API.new(endpoint: tenant.endpoint, provider_key: tenant.access_token)
  end

  def call(model)
    case record = model.record
    when Service
      fetch_service(model)
    when Application
      fetch_application(model)
    else
      raise UnsupportedModel, "unsupported model #{record.class}"
    end
  end

  def fetch_service(model)
    build_entry(model)
  end

  def fetch_application(model)
    client = build_client(model.tenant)

    begin
      application = client.show_application(model.record_id)
      # right now the client raises runtime error, but rather should return a result
    rescue RuntimeError
      application = nil # 404'd
    end

    build_entry(model, data: application)
  end

  def build_entry(model, **attributes)
    Entry.for_model(model).tap do |entry|
      entry.assign_attributes attributes
      Rails.logger.info "[FetchService] got Entry: #{entry.attributes.compact}"
    end
  end
end
