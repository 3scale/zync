# frozen_string_literal: true

require 'sinatra'
require 'json'
require 'yaml/store'

$store = YAML::Store.new('clients.yml')
$basic_auth =  Rack::Auth::Basic.new(->(_) { [] }, 'REST API') do |username, password|
  username.length > 0 && password.length > 0
end

def json(object)
  headers 'Content-Type' => 'application/json'
  body JSON(object)
end

get '/.well-known/openid-configuration' do
  # point zync where to exchange the OAuth2 access token
  json({ token_endpoint: 'https://example.com/auth/realms/master/protocol/openid-connect/token' })
end

put '/clients/:client_id' do |client_id|
  # {"client_id"=>"ee305610",
  #  "client_secret"=>"ac0e42db426b4377096c6590e2b06aed",
  #  "client_name"=>"oidc-app",
  #  "redirect_uris"=>["http://example.com"],
  #  "grant_types"=>["client_credentials", "password"]}
  client = JSON.parse(request.body.read)

  # store the client
  $store.transaction do
    $store[client_id] = client
  end

  json(client)
end

delete '/clients/:client_id' do |client_id|
  # Request HTTP Basic authentication
  if (status, headers, body = $basic_auth.call(env))
    self.headers headers
    error status, body
  end

  client = nil

  # remove the client
  $store.transaction do
    client = $store[client_id]
    $store.delete(client_id)
  end

  json(client)
end
