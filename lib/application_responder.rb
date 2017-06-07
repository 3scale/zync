# frozen_string_literal: true

# Main Responder used by the ApplicationController
# It is used to handle the #respond_with responses

class ApplicationResponder < ActionController::Responder

  def api_behavior
    if put?
      display resource, status: :created
    else
      super
    end
  end
end
