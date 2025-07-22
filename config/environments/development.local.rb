# Configurações específicas para desenvolvimento local
# Espelhando configurações de produção

Rails.application.configure do
  # Configurações básicas de desenvolvimento
  config.cache_classes = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  # Cache store (usando Redis como produção)
  config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }

  # Active Storage (local como produção)
  config.active_storage.variant_processor = :mini_magick

  # Action Mailer (usando configurações de produção)
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }

  # SMTP settings (espelhando produção)
  config.action_mailer.smtp_settings = {
    address: ENV['SMTP_ADDRESS'],
    port: ENV['SMTP_PORT'],
    domain: ENV['SMTP_DOMAIN'],
    user_name: ENV['SMTP_USERNAME'],
    password: ENV['SMTP_PASSWORD'],
    authentication: ENV['SMTP_AUTHENTICATION'],
    enable_starttls_auto: ENV['SMTP_ENABLE_STARTTLS_AUTO'] == 'true',
    openssl_verify_mode: ENV['SMTP_OPENSSL_VERIFY_MODE'],
    ssl: ENV['SMTP_SSL'] == 'true'
  }

  # Logging (como produção)
  config.log_level = :debug
  config.log_tags = [:request_id]

  # Assets (compilados como produção para testes)
  config.assets.debug = false
  config.assets.compile = true
  config.assets.digest = true

  # Force SSL (desabilitado para desenvolvimento)
  config.force_ssl = false

  # Configurações específicas do Chatwoot
  config.hosts.clear # Permitir qualquer host em desenvolvimento

  # Active Job (usando Sidekiq como produção)
  config.active_job.queue_adapter = :sidekiq

  # Configurações de sessão
  config.session_store :cookie_store, key: '_chatwoot_session'

  # Configurações de CORS para desenvolvimento
  config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins '*'
      resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head]
    end
  end

  # Configurações específicas para espelhar produção
  config.time_zone = ENV['TZ'] || 'America/Sao_Paulo'
  config.i18n.default_locale = ENV['DEFAULT_LOCALE']&.to_sym || :pt_BR

  # Configurações de performance (reduzidas para desenvolvimento)
  config.web_console.permissions = '0.0.0.0/0'
  
  # Configurações de Active Record
  config.active_record.verbose_query_logs = true
  config.active_record.migration_error = :page_load

  # Configurações de arquivo
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
end
