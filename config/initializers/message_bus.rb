# This is very similar to ActiveRecord::ConnectionHandling#postgresql_connection(config)

connection_info = ActiveRecord::Base.connection_config.deep_dup
connection_info[:user] = connection_info.delete(:username)
connection_info[:dbname] = connection_info.delete(:database)
connection_info.slice!(*PG::Connection.conndefaults_hash.keys)

MessageBus.configure(backend: :postgres, backend_options: connection_info)

tenant_lookup = lambda do |env = {}|
  Rails.application.reloader.wrap do
    request = ActionDispatch::Request.new(env)
    tenant_id, access_token = ActionController::HttpAuthentication::Basic.user_name_and_password(request)

    env['message_bus.tenant'] ||= Tenant.find_by(access_token: access_token, id: tenant_id)&.to_gid_param
  end
end

MessageBus.configure(site_id_lookup: tenant_lookup, user_id_lookup: tenant_lookup)
