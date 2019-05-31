# frozen_string_literal: true

# Handles persisting/removing clients using the Generic HTTP adapter.
class Integration::GenericService < Integration::AbstractService
  self.adapter_class = ::GenericAdapter

  def remove(client)
    payload = { client: client, adapter: adapter }

    ActiveSupport::Notifications.instrument('remove_client.oidc', payload) do
      adapter.delete_client(client)
    end
  end

  def persist(client)
    payload = { client: client, adapter: adapter }

    ActiveSupport::Notifications.instrument('update_client.oidc', payload) do
      adapter.update_client(client)
    end
  end

  protected

  def client_params(data)
    params = ActionController::Parameters.new(data)
    params.permit(:client_id, :client_secret, :redirect_url,
                  :enabled, :name, oidc_configuration: OIDC_FLOWS)
  end

  def persist?(client)
    client.enabled?
  end
end
