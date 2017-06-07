# frozen_string_literal: true
Rails.application.routes.draw do
  resource :notification, only: %i[update]
end
