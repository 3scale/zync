# frozen_string_literal: true

class Integration::KeycloakService
  attr_reader :integration, :adapter

  def initialize(integration)
    @integration = integration
    @adapter = ::Keycloak.new(integration.endpoint)
    freeze
  end

  def call(entry)
    case entry.record
    when Proxy then handle_test
    when Application then handle_application(entry)
    else handle_rest(entry)
    end
  end

  def handle_application(entry)
    client = build_client(entry)

    unless client.id
      # Not OAuth
      return
    end

    if persist?(client)
      persist(client)
    else
      remove(client)
    end
  end

  def handle_test
    @adapter.test
  end

  def handle_rest(entry)
    Rails.logger.debug { "[#{self.class.name}] skipping #{entry.to_gid} of record #{entry.record.to_gid}" }
  end

  EMPTY_DATA = {}.with_indifferent_access.freeze
  private_constant :EMPTY_DATA

  def client_id(entry)
    return unless entry.model.record_type == 'Application'
    (entry.data || entry.previous_data).fetch('client_id') { return }
  end

  def persist?(client)
    client.secret
  end

  def build_client(entry)
    data = entry.data

    client = Keycloak::Client.new(id: client_id(entry))

    params = client_params(data || {})
    client.assign_attributes(params)

    client
  end

  def client_params(data)
    params = ActionController::Parameters.new(data)
    params.permit(:client_id, :client_secret, :redirect_url, :state, :name, :description)
  end

  def remove(client)
    payload = { client: client, adapter: adapter }

    ActiveSupport::Notifications.instrument('remove_client.oidc', payload) do
      adapter.delete_client(client)
    end
  end

  def persist(client)
    update_client = Concurrent::SafeTaskExecutor.new(method(:update_client))
    updated, value, _error = update_client.execute(client)

    updated ? value : adapter.create_client(client)
  end

  def create_client(client)
    payload = { client: client, adapter: adapter }

    ActiveSupport::Notifications.instrument('create_client.oidc', payload) do
      adapter.create_client(client)
    end
  end

  def update_client(client)
    payload = { client: client, adapter: adapter }

    ActiveSupport::Notifications.instrument('update_client.oidc', payload) do
      adapter.update_client(client)
    end
  end
end
