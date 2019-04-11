# frozen_string_literal: true
Rails.application.routes.draw do
  mount Que::Web => "/que"

  Que::Web.use(Rack::Auth::Basic) do |user,password|
    token = Rails.application.secrets.authentication[:token].presence

    next true unless token

    ActiveSupport::SecurityUtils.secure_compare(user.presence || password.presence || '', token || '')
  end

  defaults format: :json do
    resource :notification, only: %i[update]
    resource :tenant, only: %i[update]

    namespace :status do
      resource :live, only: %i[show]
      resource :ready, only: %i[show]
    end
  end
end
