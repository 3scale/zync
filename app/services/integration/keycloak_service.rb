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
    when Application then ClientFromApplication.call(entry)
    when Client then handle_client(entry)
    else handle_rest(entry)
    end
  end

  def handle_client(entry)
    client = build_client(entry)

    if persist?(client)
      persist(client)
    else
      remove(client)
    end
  end

  # Convert Application to Client and trigger new update from the API.
  # Creates new Client if needed and triggers UpdateJob for it.
  class ClientFromApplication
    def self.call(entry)
      new(entry).call
    end

    attr_reader :tenant, :client_id, :scope

    def initialize(entry)
      @client_id = entry.last_known_data.dig('client_id')
      @tenant = entry.tenant
      @scope = Client.for_service(entry.record.service)
    end

    def call
      return unless client_id

      model = Model.create_record!(tenant) do
        scope.find_or_create_by!(client_id: client_id)
      end

      UpdateJob.perform_later(model)

      model
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
    case entry.model.weak_record
    when Client
      (entry.data || entry.previous_data).fetch('client_id') { return }
    else
      return
    end
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

  OIDC_FLOWS = %i[
    standard_flow_enabled implicit_flow_enabled service_accounts_enabled direct_access_grants_enabled
  ].freeze
  private_constant :OIDC_FLOWS

  def client_params(data)
    params = ActionController::Parameters.new(data)
    params.permit(:client_id, :client_secret, :redirect_url,
                  :state, :enabled, :name, :description,
                  oidc_configuration: OIDC_FLOWS)
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
