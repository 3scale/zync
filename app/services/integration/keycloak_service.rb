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

    unless client
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

  def build_client(entry)
    model = entry.model
    data = entry.data

    return unless model.record_type == 'Application'
    client_id = (data || entry.previous_data).fetch('client_id') { return }

    client = Keycloak::Client.new(id: client_id)

    return client unless data
    return unless data.key?('client_id') # not OAuth integration

    params = ActionController::Parameters.new(data)
    client.assign_attributes(params.permit(:client_id, :client_secret, :redirect_url))

    client
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
