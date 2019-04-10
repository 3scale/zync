# frozen_string_literal: true
#
namespace :simulate do

end

task simulate: :environment do
  require 'rails/console/app'
  include Rails::ConsoleMethods

  endpoint = URI('http://localhost:3000/simulate/')

  app = new_session do |session|
    session.host! "#{endpoint.host}:#{endpoint.port}"
  end

  id = 1
  app.put app.tenant_url(format: :json), params: { tenant: { id: id, access_token: 'foobar', endpoint: endpoint.to_s } }

  app.put app.notification_url(format: :json),
      params: { type: 'Service', id: 1, tenant_id: id }
  app.put app.notification_url(format: :json),
      params: { type: 'Proxy', id: 1, service_id: 1, tenant_id: id }
  app.put app.notification_url(format: :json),
      params: { type: 'Application', id: 1, service_id: 1, tenant_id: id }
end
