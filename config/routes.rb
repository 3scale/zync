# frozen_string_literal: true
Rails.application.routes.draw do
  defaults format: :json do
    resource :notification, only: %i[update]
    resource :tenant, only: %i[update]
  end
end
