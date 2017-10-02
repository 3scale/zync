# frozen_string_literal: true
require '3scale/api/http_client'

# Custom HTTP Client for 3scale API client with added instrumentation.,
class ThreeScale::API::InstrumentedHttpClient < ThreeScale::API::HttpClient

  def get(path, params: nil)
    req = build_request(Net::HTTP::Get, path, params)
    parse request(req)
  end

  def patch(path, body: , params: nil)
    req = build_request(Net::HTTP::Patch, path, params)

    parse request(req, body)
  end

  def post(path, body: , params: nil)
    req = build_request(Net::HTTP::Post, path, params)

    parse request(req, body)
  end

  def put(path, body: nil, params: nil)
    req = build_request(Net::HTTP::Put, path, params)

    parse request(req, body)
  end

  def delete(path, params: nil)
    req = build_request(Net::HTTP::Delete, path, params)

    parse request(req)
  end

  def parse(response)
    case response
      when Net::HTTPNotFound then nil
      else super
    end
  end

  protected

  def build_request(type, path, params)
    uri = format_path_n_query(path, params)
    type.new(uri, headers)
  end

  def request(req, body = nil)
    instrument('request.three_scale_api_client', build_payload(req)) do |payload|
      response = @http.request(req, body)

      payload[:response] = response.code

      if req.response_body_permitted?
        response.read_body
      end

      response
    end
  end

  def build_payload(req, params: nil)
    { uri: endpoint.merge(req.path).to_s, path: req.path, params: params, method: req.method, adapter: self }
  end

  delegate :instrument, to: 'ActiveSupport::Notifications'
end