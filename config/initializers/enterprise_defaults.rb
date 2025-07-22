# frozen_string_literal: true

# Configure enterprise defaults for Chatwoot installations
Rails.application.config.after_initialize do
  # Only run if database is available
  next unless ActiveRecord::Base.connection.table_exists?('installation_configs')

  begin
    Rails.logger.info '[ENTERPRISE_DEFAULTS] Ensuring enterprise configuration is set'

    # Ensure INSTALLATION_PRICING_PLAN is set to enterprise
    plan_config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN')
    if plan_config.value != 'enterprise'
      plan_config.value = 'enterprise'
      plan_config.save!
      Rails.logger.info '[ENTERPRISE_DEFAULTS] Set pricing plan to enterprise'
    end

    # Ensure INSTALLATION_PRICING_PLAN_QUANTITY is set to 9999999
    quantity_config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')
    if quantity_config.value != 9_999_999
      quantity_config.value = 9_999_999
      quantity_config.save!
      Rails.logger.info '[ENTERPRISE_DEFAULTS] Set pricing plan quantity to 9,999,999'
    end

    # Clear Redis premium warning if it exists
    if defined?(Redis::Alfred)
      begin
        Redis::Alfred.delete(Redis::Alfred::CHATWOOT_INSTALLATION_CONFIG_RESET_WARNING)
        Rails.logger.info '[ENTERPRISE_DEFAULTS] Cleared Redis premium warning flag'
      rescue StandardError => e
        Rails.logger.warn "[ENTERPRISE_DEFAULTS] Could not clear Redis flag: #{e.message}"
      end
    end

    # Clear cache to ensure changes take effect
    GlobalConfig.clear_cache

    Rails.logger.info '[ENTERPRISE_DEFAULTS] Enterprise configuration completed successfully'

  rescue StandardError => e
    Rails.logger.error "[ENTERPRISE_DEFAULTS] Error setting enterprise defaults: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
