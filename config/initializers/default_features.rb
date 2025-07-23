# frozen_string_literal: true

# Configure default features for new accounts
Rails.application.config.after_initialize do
  # Skip during assets precompilation, console, test, or when database is not needed
  next if defined?(Rails::Console) || Rails.env.test? ||
          ENV['RAILS_GROUPS']&.include?('assets') ||
          ENV['PRECOMPILE_ASSETS'] == 'true'

  # Only run in production and if database is available
  next unless Rails.env.production?

  # Check if database connection is available and table exists
  begin
    # Skip if we can't establish a connection or if ActiveRecord is not ready
    next unless defined?(ActiveRecord::Base)
    next unless ActiveRecord::Base.connection_pool.connected?
    next unless ActiveRecord::Base.connection.table_exists?('installation_configs')
  rescue ActiveRecord::NoDatabaseError, PG::ConnectionBad, ActiveRecord::ConnectionNotEstablished, StandardError => e
    Rails.logger.info "[DEFAULT_FEATURES] Database not available (#{e.class}), skipping feature configuration"
    next
  end

  begin
    # Ensure ACCOUNT_LEVEL_FEATURE_DEFAULTS configuration exists
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')

    if config.blank?
      Rails.logger.info '[DEFAULT_FEATURES] Creating ACCOUNT_LEVEL_FEATURE_DEFAULTS configuration'

      # Load features from configuration file
      features = YAML.safe_load(File.read(Rails.root.join('config/features.yml')))

      # Features that should be enabled by default for new accounts
      default_enabled_features = %w[
        whatsapp_campaign
        whatsapp_embedded_signup
        captain_integration
      ]

      # Enable default features
      updated_features = features.map do |feature|
        if default_enabled_features.include?(feature['name'])
          Rails.logger.info "[DEFAULT_FEATURES] Enabling feature by default: #{feature['name']}"
          feature.merge('enabled' => true)
        else
          feature
        end
      end

      # Create configuration
      InstallationConfig.create!(
        name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS',
        value: updated_features,
        locked: true
      )

      Rails.logger.info "[DEFAULT_FEATURES] Configuration created with #{updated_features.size} features"
      Rails.logger.info "[DEFAULT_FEATURES] Default enabled features: #{default_enabled_features.join(', ')}"
    else
      # Ensure default features are enabled in existing configuration
      default_enabled_features = %w[
        whatsapp_campaign
        whatsapp_embedded_signup
        captain_integration
      ]

      updated_features = config.value.map do |feature|
        if default_enabled_features.include?(feature['name']) && !feature['enabled']
          Rails.logger.info "[DEFAULT_FEATURES] Enabling feature: #{feature['name']}"
          feature.merge('enabled' => true)
        else
          feature
        end
      end

      # Update configuration if changes were made
      if updated_features != config.value
        config.update!(value: updated_features)
        Rails.logger.info '[DEFAULT_FEATURES] Configuration updated with default enabled features'
      end
    end

    # Clear cache to ensure changes take effect
    GlobalConfig.clear_cache if defined?(GlobalConfig)

  rescue StandardError => e
    Rails.logger.error "[DEFAULT_FEATURES] Error configuring default features: #{e.message}"
  end
end
