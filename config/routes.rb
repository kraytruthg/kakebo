Rails.application.routes.draw do
  resource :session, only: [:new, :create, :destroy]
  get "signup", to: "users#new"
  resources :users, only: [:create]
  get "budget", to: "budget#index", as: :budget
  post "budget/copy_from_previous", to: "budget#copy_from_previous", as: :budget_copy_from_previous
  resources :budget_entries, only: [:create]
  get "budget_entries/edit", to: "budget_entries#edit", as: :edit_budget_entries
  resources :accounts, only: [:index, :show, :new, :create, :edit, :update] do
    resources :transactions, only: [:create, :destroy]
  end
  get "reports", to: "reports#index", as: :reports

  namespace :settings do
    resources :category_groups, only: [:new, :create, :edit, :update, :destroy] do
      resources :categories, only: [:new, :create, :edit, :update, :destroy]
    end
  end
  get "settings/categories", to: "settings/category_groups#index", as: :settings_categories

  root "budget#index"
  get "up" => "rails/health#show", as: :rails_health_check
end
