# Evolution API methods to be added to Channel::Api model
# These methods will be injected into the existing model without overwriting it

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
