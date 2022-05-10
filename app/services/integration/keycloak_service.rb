# frozen_string_literal: true

class Integration::KeycloakService < Integration::AbstractService
  self.adapter_class = ::KeycloakAdapter

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

  protected

  def persist?(client)
    client.secret
  end
end
