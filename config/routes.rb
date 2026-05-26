SlashMigrate::Engine.routes.draw do
  root to: "tables#index"

  resources :tables, only: [:index, :show] do
    resources :columns, only: [:new, :create, :edit, :update], param: :name do
      post :preview, on: :collection
      member do
        post :drop
        post :update_preview
      end
    end
  end

  resources :models, only: [:new, :create] do
    post :preview, on: :collection
  end

  # The engine serves its own JS/CSS so it never depends on the host app's asset
  # pipeline (importmap / esbuild / Sprockets / Propshaft). See AssetsController.
  get "assets/:name", to: "assets#show", as: :asset_file, constraints: {name: /[\w.-]+/}
end
