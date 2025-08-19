# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Channel::Api do
  # This validation happens in ApplicationRecord
  describe 'length validations' do
    let(:channel_api) { create(:channel_api) }

    context 'when it validates webhook_url length' do
      it 'valid when within limit' do
        channel_api.webhook_url = 'a' * Limits::URL_LENGTH_LIMIT
        expect(channel_api.valid?).to be true
      end

      it 'invalid when crossed the limit' do
        channel_api.webhook_url = 'a' * (Limits::URL_LENGTH_LIMIT + 1)
        channel_api.valid?
        expect(channel_api.errors[:webhook_url]).to include("is too long (maximum is #{Limits::URL_LENGTH_LIMIT} characters)")
      end
    end
  end

  describe 'Evolution API methods' do
    let(:account) { create(:account) }
    let(:inbox) { create(:inbox, account: account, channel: channel_api) }
    let(:channel_api) { create(:channel_api, account: account) }

    before do
      allow(Rails.application.credentials).to receive(:dig).with(:evolution_api, :url).and_return('https://evo.test.com')
      allow(ENV).to receive(:[]).with('EVOLUTION_API_URL').and_return('https://evo.test.com')
      channel_api.update!(inbox: inbox)
    end

    describe '#evolution_webhook_configured?' do
      it 'returns false when webhook_url is nil' do
        channel_api.webhook_url = nil
        expect(channel_api.evolution_webhook_configured?).to be false
      end

      it 'returns false when webhook_url does not contain chatwoot/webhook/' do
        channel_api.webhook_url = 'https://example.com/other/webhook'
        expect(channel_api.evolution_webhook_configured?).to be false
      end

      it 'returns true when webhook_url contains chatwoot/webhook/' do
        channel_api.webhook_url = 'https://evo.test.com/chatwoot/webhook/test_instance'
        expect(channel_api.evolution_webhook_configured?).to be true
      end
    end

    describe '#evolution_instance_name' do
      it 'returns nil when webhook is not configured' do
        channel_api.webhook_url = nil
        expect(channel_api.evolution_instance_name).to be_nil
      end

      it 'extracts instance name from webhook URL' do
        channel_api.webhook_url = 'https://evo.test.com/chatwoot/webhook/test_instance_123'
        expect(channel_api.evolution_instance_name).to eq('test_instance_123')
      end
    end

    describe '#has_evolution_instance?' do
      it 'returns false when webhook is not configured' do
        channel_api.webhook_url = nil
        expect(channel_api.has_evolution_instance?).to be false
      end

      it 'returns true when webhook is configured and instance name exists' do
        channel_api.webhook_url = 'https://evo.test.com/chatwoot/webhook/test_instance'
        expect(channel_api.has_evolution_instance?).to be true
      end
    end

    describe '#generate_evolution_instance_name' do
      it 'returns nil when inbox is not present' do
        channel_api.update!(inbox: nil)
        expect(channel_api.generate_evolution_instance_name).to be_nil
      end

      it 'generates instance name with correct format' do
        expected_name = "#{inbox.account_id}_#{inbox.id}_#{channel_api.identifier}"
        expect(channel_api.generate_evolution_instance_name).to eq(expected_name)
      end
    end

    describe '#evolution_webhook_url' do
      it 'returns nil when base URL is not configured' do
        allow(Rails.application.credentials).to receive(:dig).with(:evolution_api, :url).and_return(nil)
        allow(ENV).to receive(:[]).with('EVOLUTION_API_URL').and_return(nil)

        expect(channel_api.evolution_webhook_url).to be_nil
      end

      it 'generates webhook URL with instance name' do
        instance_name = 'test_instance'
        expected_url = 'https://evo.test.com/chatwoot/webhook/test_instance'

        expect(channel_api.evolution_webhook_url(instance_name)).to eq(expected_url)
      end

      it 'generates webhook URL with auto-generated instance name' do
        expected_instance_name = "#{inbox.account_id}_#{inbox.id}_#{channel_api.identifier}"
        expected_url = "https://evo.test.com/chatwoot/webhook/#{expected_instance_name}"

        expect(channel_api.evolution_webhook_url).to eq(expected_url)
      end
    end
  end
end
