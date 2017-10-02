# frozen_string_literal: true
module Lograge

  # Extract Controller params from events and add them as custom options to lograge.
  module CustomOptions
    module_function

    NO_PARAMS = {}.freeze

    def call(event)
      params = event.payload.fetch(:params) { return NO_PARAMS } || NO_PARAMS

      { params: params.except(*ActionController::LogSubscriber::INTERNAL_PARAMS) }
    end
  end
end