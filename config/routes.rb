Rails.application.routes.draw do
  resource :notification, only: %i[update]
end
