Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  post '/order-created' => 'order#change_carton_inventory'
  post '/refund-created' => 'order#refund_carton_inventory'

  # Defines the root path route ("/")
  # root "articles#index"
end
