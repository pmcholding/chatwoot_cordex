# frozen_string_literal: true

class Api::V1::Accounts::Inboxes::EvolutionWhatsappController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :ensure_api_channel
  before_action :initialize_evolution_service

  def initialize_instance
    # Generate instance name from current inbox configuration
    instance_name = if @inbox.channel.has_evolution_instance?
                      @inbox.channel.evolution_instance_name
                    else
                      @inbox.channel.generate_evolution_instance_name
                    end

    webhook_url = @inbox.channel.evolution_webhook_url(instance_name)

    begin
      # Try to get connection state first to check if instance exists
      connection_state = @evolution_service.get_connection_state(instance_name)

      # Instance exists, return its state
      render json: {
        instance_name: instance_name,
        webhook_url: webhook_url,
        connection_state: connection_state,
        existing_instance: true
      }
    rescue StandardError => e
      # If instance doesn't exist (404 error), create it
      raise e unless e.message.include?('Not Found') || e.message.include?('does not exist')

      Rails.logger.info "Instance #{instance_name} does not exist, creating new instance"

      result = @evolution_service.create_instance(instance_name, @inbox.account_id, @inbox.name)

      # Save webhook URL to database if not already saved
      @inbox.channel.update!(webhook_url: webhook_url) unless @inbox.channel.webhook_url == webhook_url

      # Get initial connection state after creation
      begin
        connection_state = @evolution_service.get_connection_state(instance_name)
      rescue StandardError => state_error
        Rails.logger.warn "Could not get connection state after creation: #{state_error.message}"
        connection_state = { instance: { state: 'close' } }
      end

      render json: {
        instance_name: instance_name,
        webhook_url: webhook_url,
        connection_state: connection_state,
        existing_instance: false,
        creation_result: result
      }
    end
  rescue StandardError => e
    Rails.logger.error "Evolution API Error: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def connection_status
    instance_name = @inbox.channel.evolution_instance_name
    return render json: { error: 'No Evolution instance configured' }, status: :not_found unless instance_name

    connection_state = @evolution_service.get_connection_state(instance_name)

    # If connected, also get settings
    settings = nil
    if connection_state.dig('instance', 'state') == 'open'
      begin
        settings = @evolution_service.get_settings(instance_name)
      rescue StandardError => e
        Rails.logger.warn "Could not fetch settings: #{e.message}"
      end
    end

    render json: {
      instance_name: instance_name,
      connection_state: connection_state,
      settings: settings
    }
  rescue StandardError => e
    Rails.logger.error "Evolution API Error: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def connect_qr_code
    instance_name = @inbox.channel.evolution_instance_name
    return render json: { error: 'No Evolution instance configured' }, status: :not_found unless instance_name

    begin
      result = @evolution_service.connect_instance(instance_name)

      render json: {
        instance_name: instance_name,
        qr_code: result['base64'],
        pairing_code: result['pairingCode'],
        count: result['count']
      }
    rescue StandardError => e
      # If instance doesn't exist, try to initialize it first
      raise e unless e.message.include?('Not Found') || e.message.include?('does not exist')

      Rails.logger.info "Instance #{instance_name} does not exist, initializing instance first"

      # Call initialize_instance to create the instance
      initialize_instance
      return
    end
  rescue StandardError => e
    Rails.logger.error "Evolution API Error: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def disconnect
    instance_name = @inbox.channel.evolution_instance_name
    return render json: { error: 'No Evolution instance configured' }, status: :not_found unless instance_name

    result = @evolution_service.disconnect_instance(instance_name)

    render json: {
      instance_name: instance_name,
      message: 'Instance disconnected successfully',
      result: result
    }
  rescue StandardError => e
    Rails.logger.error "Evolution API Error: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def connect_with_number
    instance_name = @inbox.channel.evolution_instance_name
    return render json: { error: 'No Evolution instance configured' }, status: :not_found unless instance_name

    phone_number = params[:phone_number]
    return render json: { error: 'Phone number is required' }, status: :bad_request if phone_number.blank?

    result = @evolution_service.connect_instance(instance_name, phone_number)

    render json: {
      instance_name: instance_name,
      pairing_code: result['pairingCode'],
      phone_number: phone_number
    }
  rescue StandardError => e
    Rails.logger.error "Evolution API Error: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update_settings
    instance_name = @inbox.channel.evolution_instance_name
    return render json: { error: 'No Evolution instance configured' }, status: :not_found unless instance_name

    settings = params[:settings]
    return render json: { error: 'Settings are required' }, status: :bad_request if settings.blank?

    result = @evolution_service.update_settings(instance_name, settings.permit!)

    render json: {
      instance_name: instance_name,
      settings: result,
      success: true
    }
  rescue StandardError => e
    Rails.logger.error "Evolution API Error: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def webhook_info
    render json: {
      webhook_configured: @inbox.channel.evolution_webhook_configured?,
      webhook_url: @inbox.channel.webhook_url,
      instance_name: @inbox.channel.evolution_instance_name,
      has_instance: @inbox.channel.has_evolution_instance?
    }
  end

  def instance_settings
    instance_name = @inbox.channel.evolution_instance_name
    settings = @evolution_service.get_instance_settings(instance_name)
    render json: { settings: settings }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, :show?
  end

  def ensure_api_channel
    return if @inbox.channel.is_a?(Channel::Api)

    render json: { error: 'This feature is only available for API channels' }, status: :unprocessable_entity
  end

  def initialize_evolution_service
    # Get the current user's access token for Evolution API
    user_token = Current.user&.access_token&.token
    @evolution_service = EvolutionApiService.new(user_token: user_token)
  rescue StandardError => e
    render json: { error: "Evolution API configuration error: #{e.message}" }, status: :service_unavailable
  end
end
