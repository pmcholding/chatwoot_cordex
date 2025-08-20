# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EvolutionApiService do
  let(:user_token) { 'test-user-token' }
  let(:service) { described_class.new(user_token: user_token) }
  let(:instance_name) { 'test_instance' }
  let(:account_id) { 1 }
  let(:inbox_name) { 'Test Inbox' }

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:evolution_api, :url).and_return('https://test-api.com')
    allow(Rails.application.credentials).to receive(:dig).with(:evolution_api, :key).and_return('test-key')
    allow(Rails.application.credentials).to receive(:dig).with(:evolution_api, :chatwoot_token).and_return('test-token')
    allow(Rails.application.credentials).to receive(:dig).with(:evolution_api, :frontend_url).and_return('https://test-frontend.com')

    # Fallback to ENV if credentials are not set
    allow(ENV).to receive(:[]).with('EVOLUTION_API_URL').and_return('https://test-api.com')
    allow(ENV).to receive(:[]).with('EVOLUTION_API_KEY').and_return('test-key')
    allow(ENV).to receive(:[]).with('CHATWOOT_TOKEN').and_return('test-token')
    allow(ENV).to receive(:[]).with('FRONTEND_URL').and_return('https://test-frontend.com')
  end

  describe '#initialize' do
    it 'sets up the service with correct configuration using user token' do
      expect(service.instance_variable_get(:@base_url)).to eq('https://test-api.com')
      expect(service.instance_variable_get(:@api_key)).to eq('test-key')
      expect(service.instance_variable_get(:@chatwoot_token)).to eq('test-user-token')
      expect(service.instance_variable_get(:@frontend_url)).to eq('https://test-frontend.com')
    end

    it 'falls back to environment token when user token is not provided' do
      service_without_token = described_class.new
      expect(service_without_token.instance_variable_get(:@chatwoot_token)).to eq('test-token')
    end

    it 'raises error when configuration is missing' do
      allow(Rails.application.credentials).to receive(:dig).and_return(nil)
      allow(ENV).to receive(:[]).and_return(nil)
      allow(ENV).to receive(:fetch).and_return(nil)

      expect { described_class.new }.to raise_error('Evolution API configuration missing')
    end
  end

  describe '#create_instance' do
    let(:expected_payload) do
      {
        instanceName: instance_name,
        integration: 'WHATSAPP-BAILEYS',
        chatwootAccountId: account_id.to_s,
        chatwootToken: 'test-user-token',
        chatwootUrl: 'https://test-frontend.com',
        chatwootSignMsg: false,
        chatwootReopenConversation: false,
        chatwootConversationPending: false,
        chatwootImportContacts: false,
        chatwootNameInbox: inbox_name,
        chatwootMergeBrazilContacts: false,
        chatwootImportMessages: false,
        chatwootDaysLimitImportMessages: 7
      }
    end

    it 'creates an instance with correct payload' do
      response_double = double('response', code: 201, parsed_response: { 'success' => true })
      allow(described_class).to receive(:post).with('/instance/create', body: expected_payload.to_json).and_return(response_double)

      result = service.create_instance(instance_name, account_id, inbox_name)

      expect(result).to eq({ 'success' => true })
    end
  end

  describe '#get_connection_state' do
    it 'gets connection state for instance' do
      response_double = double('response', code: 200, parsed_response: { 'instance' => { 'state' => 'open' } })
      allow(described_class).to receive(:get).with("/instance/connectionState/#{instance_name}").and_return(response_double)

      result = service.get_connection_state(instance_name)

      expect(result).to eq({ 'instance' => { 'state' => 'open' } })
    end
  end

  describe '#connect_instance' do
    it 'connects instance without phone number' do
      response_double = double('response', code: 200, parsed_response: { 'code' => 'qr-code-data' })
      allow(described_class).to receive(:get).with("/instance/connect/#{instance_name}").and_return(response_double)

      result = service.connect_instance(instance_name)

      expect(result).to eq({ 'code' => 'qr-code-data' })
    end

    it 'connects instance with phone number' do
      phone_number = '+1234567890'
      response_double = double('response', code: 200, parsed_response: { 'pairingCode' => 'ABC123' })
      allow(described_class).to receive(:get).with("/instance/connect/#{instance_name}?number=#{phone_number}").and_return(response_double)

      result = service.connect_instance(instance_name, phone_number)

      expect(result).to eq({ 'pairingCode' => 'ABC123' })
    end
  end

  describe '#update_settings' do
    let(:settings) do
      {
        reject_call: true,
        msg_call: 'Test message',
        groups_ignore: false,
        always_online: true,
        read_messages: false,
        read_status: true,
        sync_full_history: false
      }
    end

    let(:expected_payload) do
      {
        rejectCall: true,
        msgCall: 'Test message',
        groupsIgnore: false,
        alwaysOnline: true,
        readMessages: false,
        readStatus: true,
        syncFullHistory: false
      }
    end

    it 'updates settings with correct payload' do
      response_double = double('response', code: 200, parsed_response: { 'success' => true })
      allow(described_class).to receive(:post).with("/settings/set/#{instance_name}", body: expected_payload.to_json).and_return(response_double)

      result = service.update_settings(instance_name, settings)

      expect(result).to eq({ 'success' => true })
    end
  end

  describe '#handle_response' do
    it 'handles successful responses' do
      response_double = double('response', code: 200, parsed_response: { 'data' => 'test' })

      result = service.send(:handle_response, response_double)

      expect(result).to eq({ 'data' => 'test' })
    end

    it 'handles error responses' do
      response_double = double('response', code: 400, parsed_response: { 'error' => 'Bad request' })

      expect { service.send(:handle_response, response_double) }.to raise_error(StandardError, 'Bad Request: {"error" => "Bad request"}')
    end
  end
end
