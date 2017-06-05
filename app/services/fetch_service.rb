# Fetches Model information from upstream and returns the Entity.

class FetchService
  delegate :config, to: :class

  def initialize
    @client = ThreeScale::API.new(**config)
    freeze
  end

  def self.config
    Zync::Application.config.x.threescale_client.reverse_merge(endpoint: 'http://localhost:3000', provider_key: nil)
  end

  # Returned when unknown model is passed in.
  class UnsupportedModel < StandardError; end

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
    build_entry(model)
  end

  def build_entry(model, **attributes)
    Entry.new(model: model, tenant: model.tenant, **attributes)
  end
end
