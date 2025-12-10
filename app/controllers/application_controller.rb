# frozen_string_literal: true
require 'application_responder'

class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  self.responder = ApplicationResponder

  before_action :authenticate
  respond_to :json

  protected

  def authenticate
    expected_token = Rails.configuration.x.zync.authentication[:token].presence

    return unless expected_token

    authenticate_or_request_with_http_token do |token|
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(token),
        ::Digest::SHA256.hexdigest(expected_token)
      )
    end
  end
end
