Rails.application.routes.draw do
  resource :session, only: [:new, :create, :destroy]
  get "budget", to: "budget#index", as: :budget
  resources :budget_entries, only: [:create]
  get "budget_entries/edit", to: "budget_entries#edit", as: :edit_budget_entries
  resources :accounts, only: [:index, :show, :new, :create, :edit, :update] do
    resources :transactions, only: [:create, :destroy]
  end
  get "reports", to: "reports#index", as: :reports
  root "budget#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
