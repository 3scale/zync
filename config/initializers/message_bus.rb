# This is very similar to ActiveRecord::ConnectionHandling#postgresql_connection(config)

connection_info = ActiveRecord::Base.connection_db_config.configuration_hash.deep_dup
connection_info[:user] = connection_info.delete(:username)
connection_info[:dbname] = connection_info.delete(:database)
connection_info.slice!(*PG::Connection.conndefaults_hash.keys)

MessageBus.off if defined?(Rake)
MessageBus.configure(backend: :postgres, backend_options: connection_info)

MessageBus.extend(Module.new do
  def on
    @destroyed = false
    super
  end

  def destroy
    super unless @destroyed
  end
end)

MessageBus::Rack::Middleware.prepend(Module.new do
  def start_listener
    super unless MessageBus.instance_variable_get(:@off)
  end
end)

tenant_lookup = lambda do |env = {}|
  Rails.application.reloader.wrap do
    request = ActionDispatch::Request.new(env)
    tenant_id, access_token = ActionController::HttpAuthentication::Basic.user_name_and_password(request)

    tenant = Tenant.find_by(id: tenant_id)
    env['message_bus.tenant'] ||= tenant.to_gid_param if tenant&.access_token == access_token
  end
end

MessageBus.configure(site_id_lookup: tenant_lookup, user_id_lookup: tenant_lookup)
