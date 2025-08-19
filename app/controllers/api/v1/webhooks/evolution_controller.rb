class Api::V1::Webhooks::EvolutionController < ApplicationController
  skip_before_action :authenticate_user!, only: [:process_payload]
  skip_before_action :verify_authenticity_token, only: [:process_payload]

  def process_payload
    instance_name = params[:instance_name]
    return head :bad_request if instance_name.blank?

    Rails.logger.info "Evolution webhook received for instance: #{instance_name}"
    Rails.logger.info "Payload: #{params.to_json}"

    case params[:event]
    when 'messages.upsert'
      handle_message_event
    when 'connection.update'
      handle_connection_event
    when 'qrcode.updated'
      handle_qr_code_event
    else
      Rails.logger.info "Unhandled Evolution event: #{params[:event]}"
    end

    head :ok
  rescue StandardError => e
    Rails.logger.error "Evolution webhook error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    head :internal_server_error
  end

  private

  def handle_message_event
    message_data = params[:data]
    return unless message_data

    inbox = find_inbox_by_instance_name(params[:instance_name])
    return unless inbox

    # Process the message
    Rails.logger.info "Processing message for inbox: #{inbox.id}"
    # TODO: Implement message processing logic
  end

  def handle_connection_event
    Rails.logger.info "Connection update: #{params[:data]}"
  end

  def handle_qr_code_event
    Rails.logger.info "QR Code update: #{params[:data]}"
  end

  def find_inbox_by_instance_name(instance_name)
    return nil unless inbox&.channel&.is_a?(Channel::Api)

    # Find inbox by instance name in additional_attributes
    Channel::Api.joins(:inbox)
               .where(additional_attributes: { evolution_instance_name: instance_name })
               .first&.inbox
  end
end
