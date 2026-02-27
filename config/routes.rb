Rails.application.routes.draw do
  resource :session, only: [:new, :create, :destroy]
  root "budget#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
