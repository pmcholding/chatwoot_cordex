# frozen_string_literal: true

class EvolutionApiService
  include HTTParty

  def initialize(user_token: nil)
    @base_url = Rails.application.credentials.dig(:evolution_api, :url) || ENV.fetch('EVOLUTION_API_URL_V2', nil)
    @api_key = Rails.application.credentials.dig(:evolution_api, :key) || ENV.fetch('EVOLUTION_API_KEY', nil)
    @frontend_url = Rails.application.credentials.dig(:evolution_api, :frontend_url) || ENV.fetch('FRONTEND_URL', nil)

    # Use the provided user token or fallback to environment variable for backward compatibility
    @chatwoot_token = user_token || Rails.application.credentials.dig(:evolution_api, :chatwoot_token) || ENV.fetch('CHATWOOT_TOKEN', nil)

    raise 'Evolution API configuration missing' unless @base_url && @api_key && @chatwoot_token && @frontend_url

    self.class.base_uri @base_url
    self.class.headers 'apikey' => @api_key
    self.class.headers 'Content-Type' => 'application/json'
  end

  def create_instance(instance_name, account_id, inbox_name)
    payload = {
      instanceName: instance_name,
      integration: 'WHATSAPP-BAILEYS',
      chatwootAccountId: account_id.to_s,
      chatwootToken: @chatwoot_token,
      chatwootUrl: @frontend_url,
      chatwootSignMsg: false,
      chatwootReopenConversation: true,
      chatwootConversationPending: false,
      chatwootImportContacts: false,
      chatwootNameInbox: inbox_name,
      chatwootMergeBrazilContacts: false,
      chatwootImportMessages: false,
      chatwootDaysLimitImportMessages: 7
    }

    response = self.class.post('/instance/create', body: payload.to_json)
    handle_response(response)
  end

  def get_connection_state(instance_name)
    response = self.class.get("/instance/connectionState/#{instance_name}")
    handle_response(response)
  end

  def connect_instance(instance_name, phone_number = nil)
    url = "/instance/connect/#{instance_name}"
    url += "?number=#{phone_number}" if phone_number.present?

    response = self.class.get(url)
    handle_response(response)
  end

  def disconnect_instance(instance_name)
    response = self.class.delete("/instance/logout/#{instance_name}")
    handle_response(response)
  end

  def get_settings(instance_name)
    response = self.class.get("/settings/find/#{instance_name}")
    handle_response(response)
  end

  def update_settings(instance_name, settings)
    payload = {
      rejectCall: settings[:reject_call] || false,
      msgCall: settings[:msg_call] || '',
      groupsIgnore: settings[:groups_ignore] || false,
      alwaysOnline: settings[:always_online] || false,
      readMessages: settings[:read_messages] || false,
      readStatus: settings[:read_status] || false,
      syncFullHistory: settings[:sync_full_history] || false
    }

    response = self.class.post("/settings/set/#{instance_name}", body: payload.to_json)
    handle_response(response)
  end

  def delete_instance(instance_name)
    response = self.class.delete("/instance/delete/#{instance_name}")
    handle_response(response)
  end

  def get_instance_settings(instance_name)
    response = HTTParty.get(
      "#{@base_url}/settings/find/#{instance_name}",
      headers: {
        'apikey' => @api_key,
        'Content-Type' => 'application/json'
      }
    )
    handle_response(response)
  end

  private

  def handle_response(response)
    case response.code
    when 200, 201
      response.parsed_response
    when 400
      raise StandardError, "Bad Request: #{response.parsed_response}"
    when 401
      raise StandardError, 'Unauthorized: Check Evolution API key'
    when 404
      raise StandardError, "Not Found: #{response.parsed_response}"
    when 500
      raise StandardError, "Evolution API Server Error: #{response.parsed_response}"
    else
      raise StandardError, "Evolution API Error (#{response.code}): #{response.parsed_response}"
    end
  end
end
