# frozen_string_literal: true
require '3scale/api/http_client'
require 'securerandom'

# Custom HTTP Client for 3scale API client with added instrumentation.,
class ThreeScale::API::InstrumentedHttpClient < ThreeScale::API::HttpClient

  def initialize(**)
    super

    if (system_provider_port = ENV['SYSTEM_PROVIDER_PORT'].presence)
      proxy = URI(system_provider_port).freeze

      @http = Net::HTTP.new(proxy.host, proxy.port)
      @http.set_debug_output($stdout) if debug?

      @headers = headers.merge('X-Forwarded-Host' => admin_domain,
                               'X-Forwarded-Proto' =>  endpoint.scheme)
    end
  end

  def get(path, params: nil)
    req = build_request(Net::HTTP::Get, path, params)
    parse request(req, params: params)
  end

  def patch(path, body: , params: nil)
    req = build_request(Net::HTTP::Patch, path, params)

    parse request(req, body, params: params)
  end

  def post(path, body: , params: nil)
    req = build_request(Net::HTTP::Post, path, params)

    parse request(req, body, params: params)
  end

  def put(path, body: nil, params: nil)
    req = build_request(Net::HTTP::Put, path, params)

    parse request(req, body, params: params)
  end

  def delete(path, params: nil)
    req = build_request(Net::HTTP::Delete, path, params)

    parse request(req, params: params)
  end

  def parse(response)
    case response
      when Net::HTTPNotFound then nil
      else super
    end
  end

  protected

  def headers
    super.merge('X-Request-Id' => SecureRandom.uuid)
  end

  def build_request(type, path, params)
    uri = format_path_n_query(path, params)
    type.new(uri, headers)
  end

  def request(req, body = nil, params: )
    instrument('request.three_scale_api_client', build_payload(req)) do |payload|
      payload[:request_id] = req['X-Request-Id']
      payload[:params] = params

      response = @http.request(req, body)

      payload[:response] = response.code
      payload[:response_id] = response['X-Request-Id']

      if req.response_body_permitted?
        response.read_body
      end

      response
    end
  end

  def build_payload(req)
    {
        uri: endpoint.merge(req.path).to_s,
        path: req.path,
        endpoint: endpoint,
        method: req.method,
        adapter: self
    }
  end

  delegate :instrument, to: 'ActiveSupport::Notifications'
end
