# frozen_string_literal: true

class Api::V1::Webhooks::EvolutionController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :verify_authenticity_token

  def process_payload
    instance_name = params[:instance_name]
    return head :bad_request unless instance_name.present?

    # Find the inbox by instance name
    inbox = find_inbox_by_instance_name(instance_name)
    return head :not_found unless inbox

    # Process the webhook payload
    begin
      case params[:event]
      when 'messages.upsert'
        process_message_event(inbox, params[:data])
      when 'connection.update'
        process_connection_event(inbox, params[:data])
      else
        Rails.logger.info "Unhandled Evolution webhook event: #{params[:event]}"
      end

      head :ok
    rescue StandardError => e
      Rails.logger.error "Evolution webhook processing error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      head :internal_server_error
    end
  end

  private

  def find_inbox_by_instance_name(instance_name)
    # Extract account_id and inbox_id from instance name
    # Format: {account_id}_{inbox_id}_{identifier}
    parts = instance_name.split('_')
    return nil unless parts.length >= 3

    account_id = parts[0]
    inbox_id = parts[1]

    # Find the inbox
    account = Account.find_by(id: account_id)
    return nil unless account

    inbox = account.inboxes.find_by(id: inbox_id)
    return nil unless inbox&.channel&.is_a?(Channel::Api)

    # Verify the instance name matches
    return nil unless inbox.channel.evolution_instance_name == instance_name

    inbox
  end

  def process_message_event(inbox, message_data)
    # This is a simplified implementation
    # In a full implementation, you would:
    # 1. Parse the WhatsApp message format
    # 2. Create or find the contact
    # 3. Create or find the conversation
    # 4. Create the message in Chatwoot

    Rails.logger.info "Processing message event for inbox #{inbox.id}: #{message_data}"

    # Example structure for future implementation:
    # messages = message_data['messages'] || []
    # messages.each do |message|
    #   process_single_message(inbox, message)
    # end
  end

  def process_connection_event(inbox, connection_data)
    Rails.logger.info "Processing connection event for inbox #{inbox.id}: #{connection_data}"

    # Log connection state changes
    state = connection_data['state']
    Rails.logger.info "WhatsApp connection state changed to: #{state} for inbox #{inbox.id}"

    # You could implement notifications or other actions here
    # For example, notify administrators when connection is lost
  end

  def process_single_message(inbox, message)
    # Future implementation for processing individual messages
    # This would involve:
    # 1. Extracting sender information
    # 2. Creating/finding contact
    # 3. Creating/finding conversation
    # 4. Creating message with proper content type (text, image, document, etc.)
    # 5. Handling message status updates
  end
end
