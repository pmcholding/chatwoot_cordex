# == Schema Information
#
# Table name: channel_api
#
#  id                    :bigint           not null, primary key
#  additional_attributes :jsonb
#  hmac_mandatory        :boolean          default(FALSE)
#  hmac_token            :string
#  identifier            :string
#  webhook_url           :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer          not null
#
# Indexes
#
#  index_channel_api_on_hmac_token  (hmac_token) UNIQUE
#  index_channel_api_on_identifier  (identifier) UNIQUE
#

class Channel::Api < ApplicationRecord
  include Channelable

  self.table_name = 'channel_api'
  EDITABLE_ATTRS = [:webhook_url, :hmac_mandatory, { additional_attributes: {} }].freeze

  has_secure_token :identifier
  has_secure_token :hmac_token
  validate :ensure_valid_agent_reply_time_window
  validates :webhook_url, length: { maximum: Limits::URL_LENGTH_LIMIT }

  def name
    'API'
  end

  # Evolution API methods
  def evolution_webhook_configured?
    webhook_url.present? && webhook_url.include?('chatwoot/webhook/')
  end

  def evolution_instance_name
    return nil unless evolution_webhook_configured?

    # Extract instance name from webhook URL
    # Expected format: https://evo.cordex.ai/chatwoot/webhook/{instance_name}
    webhook_url.split('/').last
  end

  def has_evolution_instance?
    evolution_webhook_configured? && evolution_instance_name.present?
  end

  def generate_evolution_instance_name
    return nil unless inbox.present?

    "#{inbox.account_id}_#{inbox.id}_#{identifier}"
  end

  def evolution_webhook_url(instance_name = nil)
    instance_name ||= generate_evolution_instance_name
    return nil unless instance_name

    base_url = Rails.application.credentials.dig(:evolution_api, :url) || ENV.fetch('EVOLUTION_API_URL_V2', nil)
    return nil unless base_url

    "#{base_url}/chatwoot/webhook/#{instance_name}"
  end

  private

  def ensure_valid_agent_reply_time_window
    return if additional_attributes['agent_reply_time_window'].blank?
    return if additional_attributes['agent_reply_time_window'].to_i.positive?

    errors.add(:agent_reply_time_window, 'agent_reply_time_window must be greater than 0')
  end
end
