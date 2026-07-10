Rails.application.routes.draw do
  get "health", to: "health#show"
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users, path: "api/v1/auth", defaults: { format: :json },
             controllers: {
               sessions: "api/v1/sessions",
               registrations: "api/v1/registrations"
             }

  namespace :api do
    namespace :v1 do
      # Status
      get "status", to: "status#show"

      # Transactions / Payments
      resources :transactions, only: [:index, :show, :create] do
        member do
          post :capture
          post :refund
          post :void
          get :events
          get :ledger
        end
      end

      # Merchants — profile endpoints
      get "merchants/me", to: "merchants#me"
      patch "merchants/me", to: "merchants#update_me"
      get "merchants/me/analytics", to: "merchants#analytics"
      get "merchants/me/analytics/volume", to: "merchants#analytics_volume"
      get "merchants/me/analytics/fraud_distribution", to: "merchants#analytics_fraud_distribution"
      get "merchants/me/analytics/payment_methods", to: "merchants#analytics_payment_methods"
      get "merchants/me/analytics/recent_activity", to: "merchants#analytics_recent_activity"
      get "merchants/me/balance", to: "merchants#balance"
      # Merchants — admin CRUD
      resources :merchants, only: [:index, :show, :create]

      # Fraud
      namespace :fraud do
        resources :cases, controller: "/api/v1/fraud_cases", only: [:index, :show] do
          member do
            post :review
          end
        end
        get "stats", to: "/api/v1/fraud_cases#stats"
      end

      # Webhooks
      namespace :webhooks do
        get "deliveries", to: "/api/v1/webhooks#deliveries"
        post "test", to: "/api/v1/webhooks#test"
        get "status", to: "/api/v1/webhooks#status"
      end

      # API Keys
      resources :api_keys, only: [:index, :create, :destroy] do
        member do
          post :rotate
        end
      end
    end
  end
end
