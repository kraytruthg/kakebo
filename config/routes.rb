Rails.application.routes.draw do
  resource :session, only: [ :new, :create, :destroy ]
  resource :household_switch, only: [ :create ]
  get "onboarding", to: "onboarding#index", as: :onboarding
  get "signup", to: "users#new"
  resources :users, only: [ :create ]
  get "budget", to: "budget#index", as: :budget
  post "budget/copy_from_previous", to: "budget#copy_from_previous", as: :budget_copy_from_previous
  resources :budget_entries, only: [ :create ]
  get "budget_entries/edit", to: "budget_entries#edit", as: :edit_budget_entries
  resources :accounts, only: [ :index, :show, :new, :create, :edit, :update ] do
    resources :transactions, only: [ :create, :destroy, :edit, :update ]
  end
  resources :transfers, only: [ :new, :create, :destroy ]
  resource :quick_entry, only: [ :new, :create ], controller: "quick_entry"
  get "budget/:year/:month/categories/:category_id/transactions",
      to: "budget/category_transactions#index",
      as: :budget_category_transactions
  get "reports", to: "reports#index", as: :reports
  get "settings", to: "settings#index", as: :settings_root
  namespace :settings do
    resources :category_groups, only: [ :new, :create, :edit, :update, :destroy ] do
      collection do
        patch :reorder
      end
      resources :categories, only: [ :new, :create, :edit, :update, :destroy ] do
        collection do
          patch :reorder
        end
      end
    end
    resources :quick_entry_mappings, only: [ :index, :new, :create, :edit, :update, :destroy ]
    resources :api_tokens, only: [ :index, :create, :destroy ] do
      collection do
        patch :update_default_account
      end
    end
    resources :households, only: [ :new, :create ]
  end
  get "settings/categories", to: "settings/category_groups#index", as: :settings_categories

  namespace :admin do
    resources :users, only: [ :index, :new, :create, :edit, :update ]
  end

  namespace :api do
    namespace :v1 do
      resource :quick_entry, only: [ :create ], controller: "quick_entries"
    end
  end

  get "quick_entry/confirm/:token", to: "quick_entry_confirmations#show", as: :quick_entry_confirm
  post "quick_entry/confirm/:token", to: "quick_entry_confirmations#create"

  root to: redirect("/budget")
  get "up" => "rails/health#show", as: :rails_health_check
end
