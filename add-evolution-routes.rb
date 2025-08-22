# Evolution WhatsApp API routes to be added to config/routes.rb
# These routes will be injected into the existing routes file

# Evolution WhatsApp API routes
resources :evolution_whatsapp, only: [] do
  post :initialize_instance
  get :connection_status
  get :connect_qr_code
  delete :disconnect
  post :connect_with_number
  post :update_settings
  get :webhook_info
  get :instance_settings
end
