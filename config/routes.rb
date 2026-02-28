Rails.application.routes.draw do
  resource :session, only: [:new, :create, :destroy]
  get "budget", to: "budget#index", as: :budget
  resources :accounts do
    resources :transactions, only: [:create, :destroy]
  end
  get "reports", to: "reports#index", as: :reports
  root "budget#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
