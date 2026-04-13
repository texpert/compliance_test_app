Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get  'ais/consents',     to: 'ais_consents#index',  as: :ais_consents_list
  post 'ais/consents',     to: 'ais_consents#create', as: :ais_consents
  get  'ais/consents/:id', to: 'ais_consents#show',   as: :ais_consent
  # RESTful endpoints for accounts and transactions associated with a consent
  get 'ais/consents/:id/accounts', to: 'ais_accounts#index', as: :ais_consent_accounts
  # Also allow fetching transactions for a consent without specifying account_id
  get 'ais/consents/:id/accounts/transactions', to: 'ais_transactions#index', as: :ais_consent_transactions
  get 'ais/consents/:id/accounts/:account_id/transactions', to: 'ais_transactions#index', as: :ais_consent_account_transactions
  get 'callback/:id', to: 'ais_callbacks#show', as: :ais_callback

  root 'ais_consents#index'
end
