# frozen_string_literal: true

namespace :chatwoot do
  namespace :enterprise do
    desc 'Configure Chatwoot with enterprise defaults'
    task setup: :environment do
      puts '🚀 === Configurando Chatwoot Enterprise ==='

      begin
        # Atualiza ou cria as configurações necessárias
        plan = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN')
        plan.value = 'enterprise'
        plan.save!
        puts '✅ Plano enterprise configurado'

        quantity = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')
        quantity.value = 9_999_999
        quantity.save!
        puts '✅ Quantidade de usuários configurada (9.999.999)'

        # Remove o alerta premium do Redis, se existir
        if defined?(Redis::Alfred)
          Redis::Alfred.delete(Redis::Alfred::CHATWOOT_INSTALLATION_CONFIG_RESET_WARNING)
          puts '✅ Flag de alerta premium removida do Redis'
        else
          puts '⚠️  Redis::Alfred não está definido'
        end

        # Clear cache
        GlobalConfig.clear_cache
        puts '✅ Cache limpo'

        puts ''
        puts '🎉 === Configuração Enterprise concluída ==='
        puts '💡 Configurações aplicadas:'
        puts '   • Plano: Enterprise'
        puts '   • Usuários: 9.999.999'
        puts '   • Redis: Limpo'
        puts ''
        puts '🔄 Reinicie a aplicação para aplicar todas as mudanças'

      rescue StandardError => e
        puts "❌ Erro na configuração: #{e.message}"
        puts "   Detalhes: #{e.backtrace.first}"
        exit 1
      end
    end

    desc 'Verify enterprise configuration'
    task verify: :environment do
      puts '🔍 === Verificando configuração Enterprise ==='

      plan = InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.value
      quantity = InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')&.value

      puts "📋 Plano atual: #{plan || 'não configurado'}"
      puts "👥 Quantidade de usuários: #{quantity || 'não configurado'}"

      # Verificar fallbacks no ChatwootHub
      puts "🔧 Fallback do plano: #{ChatwootHub.pricing_plan}"
      puts "🔧 Fallback da quantidade: #{ChatwootHub.pricing_plan_quantity}"

      if plan == 'enterprise' && quantity == 9_999_999
        puts '✅ Configuração enterprise está correta!'
      else
        puts '⚠️  Configuração enterprise não está completa'
        puts '   Execute: bundle exec rake chatwoot:enterprise:setup'
      end
    end
  end
end
