Rails.application.routes.draw do

  root 'store#index'

  # Catch error conditions early.
  match '(errors)/:status', to: 'errors#show',
    constraints: {status: /\d{3}/},
    defaults: {status: '500'},
    via: :all

  # Redirect old /store route.
  get '/store', to: redirect('/front')

  # Redirect old product urls still found in the wild.
  get '/category/:category_id/product/:product_id',
    to: redirect('/product/:category_id/:product_id')

  resources :orders do
    get 'duplicate', on: :member
    get 'quote', on: :member
    resources :order_items, shallow: true
  end

  devise_for :users

  # Catch bona fide storefront urls that are not accessible via slugs.
  get  '/store/search', to: 'store#search', as: :search
  get  '/store/lookup', to: 'store#lookup', as: :lookup
  get  '/cart/delete',  to: 'store#delete_cart', as: :delete_cart
  post '/correspondence/mail_form', to: 'correspondence#mail_form',
    as: :mail_form

  # Checkout related routes.
  get  '/checkout/:order_id/via/:order_type_id', to: 'checkout#checkout',  as: :checkout
  get  '/checkout/:order_id/pay/:method', to: 'checkout#pay', as: :pay
  post '/checkout/:order_id/verify', to: 'checkout#verify', as: :verify
  get  '/checkout/:order_id/return', to: 'checkout#return', as: :return

  # Category and product views.
  get '/category/:category_id', to: 'store#show_category',
    as: :show_category
  get '/product/:category_id/:product_id', to: 'store#show_product',
    as: :show_product
  post '/product/:product_id/order', to: 'store#order_product',
    as: :order_product

  # These routes can be reached via /:slug
  get '/front', to: 'store#front', as: :front
  get '/cart',  to: 'store#cart',  as: :cart

  # If we get here, the url is seen as a slug of a page. If the page
  # is internal, its slug will match one of the above routes.
  get '/:slug', to: 'store#show_page', as: :show_page, slug: /[a-z0-9_-]+/

  namespace :admin do
    get '/dashboard', to: 'dashboard#index', as: :dashboard

    get '/reports', to: 'reports#index', as: :reports

    resources :stores do
      resources :images, shallow: true
    end
    resources :categories do
      resources :images, shallow: true
      post :reorder, on: :collection
      get :reorder_products, on: :member
    end
    resources :pages do
      resources :images, shallow: true
      post :reorder, on: :collection
    end
    resources :albums do
      resources :images, shallow: true
    end
    resources :products do
      resources :images, shallow: true
      resources :product_properties, shallow: true
      resources :iframes, shallow: true
      post :reorder, on: :collection
    end
    resources :promotions do
      resources :promoted_items, shallow: true
      post :add_products, on: :member
      post :add_categories, on: :member
    end
    resources :orders do
      resources :images, shallow: true
      resources :order_items, shallow: true
      get 'forward', on: :member
    end
    resources :properties do
      post :reorder, on: :collection
    end
    resources :users

    post '/images/reorder', to: 'images#reorder', as: :reorder_images
    post '/images/delete', to: 'images#delete', as: :delete_image
    post '/iframes/reorder', to: 'iframes#reorder', as: :reorder_iframes
  end
end
