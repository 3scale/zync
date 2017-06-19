# frozen_string_literal: true

class Integration::KeycloakService
  attr_reader :integration, :adapter

  def initialize(integration)
    @integration = integration
    @adapter = ::Keycloak.new(integration.endpoint)
    freeze
  end

  def call(entry)
    client = build_client(entry)

    unless client.id
       # Not OAuth
      return
    end

    if client.secret
      persist(client)
    else
      remove(client)
    end
  end

  EMPTY_DATA = {}.with_indifferent_access.freeze
  private_constant :EMPTY_DATA

  def client_id(entry)
    return unless entry.model.record_type == 'Application'
    (entry.data || entry.previous_data).fetch('client_id') { return }
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
    params.permit(:client_id, :client_secret, :redirect_url)
  end

  def remove(client)
    adapter.delete_client(client)
  end

  def persist(client)
    update_client = Concurrent::SafeTaskExecutor.new(adapter.method(:update_client))
    updated, value, _error = update_client.execute(client)

    updated ? value : adapter.create_client(client)
  end
end
