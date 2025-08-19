# frozen_string_literal: true

class Api::V1::Accounts::Inboxes::EvolutionWhatsappController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :ensure_api_channel
  before_action :initialize_evolution_service

  def initialize_instance
    # Check if instance already exists
    if @inbox.channel.has_evolution_instance?
      instance_name = @inbox.channel.evolution_instance_name
      connection_state = @evolution_service.get_connection_state(instance_name)

      render json: {
        instance_name: instance_name,
        webhook_url: @inbox.channel.webhook_url,
        connection_state: connection_state,
        existing_instance: true
      }
    else
      # Create new instance
      instance_name = @inbox.channel.generate_evolution_instance_name
      webhook_url = @inbox.channel.evolution_webhook_url(instance_name)

      result = @evolution_service.create_instance(instance_name, @inbox.account_id, @inbox.name)

      # Save webhook URL to database
      @inbox.channel.update!(webhook_url: webhook_url)

      # Get initial connection state
      connection_state = @evolution_service.get_connection_state(instance_name)

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

    result = @evolution_service.connect_instance(instance_name)

    render json: {
      instance_name: instance_name,
      qr_code: result['base64'],
      pairing_code: result['pairingCode'],
      count: result['count']
    }
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
    return render json: { error: 'Phone number is required' }, status: :bad_request unless phone_number.present?

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
    return render json: { error: 'Settings are required' }, status: :bad_request unless settings.present?

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
    @evolution_service = EvolutionApiService.new
  rescue StandardError => e
    render json: { error: "Evolution API configuration error: #{e.message}" }, status: :service_unavailable
  end
end
