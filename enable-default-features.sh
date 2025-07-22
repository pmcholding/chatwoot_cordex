#!/bin/bash

# Script para habilitar funcionalidades por padrão para novas contas

set -e

echo "🔧 Habilitando funcionalidades por padrão para novas contas..."

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se o serviço está rodando
if ! docker service ls 2>/dev/null | grep -q chatwoot_app; then
    print_error "Serviço chatwoot_app não está rodando!"
    exit 1
fi

print_status "Configurando funcionalidades padrão para novas contas..."

# Habilitar funcionalidades por padrão
CONTAINER_ID=$(docker ps -q -f name=chatwoot_app | head -1)
if [ -z "$CONTAINER_ID" ]; then
    print_error "Container chatwoot_app não encontrado!"
    exit 1
fi

docker exec -i $CONTAINER_ID bundle exec rails runner "
puts '🔧 Configurando funcionalidades padrão para novas contas...'

# Buscar configuração atual
config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')

if config.blank?
  puts '❌ Configuração ACCOUNT_LEVEL_FEATURE_DEFAULTS não encontrada!'
  puts 'Criando configuração padrão...'
  
  # Carregar features do arquivo de configuração
  features = YAML.safe_load(File.read(Rails.root.join('config/features.yml')))
  config = InstallationConfig.create!(
    name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS',
    value: features,
    locked: true
  )
end

puts \"✅ Configuração encontrada com #{config.value.size} features\"

# Features que queremos habilitar por padrão
features_to_enable = [
  'whatsapp_campaign',
  'whatsapp_embedded_signup',
  'captain_integration'
]

# Atualizar configuração
updated_features = config.value.map do |feature|
  if features_to_enable.include?(feature['name'])
    feature.merge('enabled' => true)
  else
    feature
  end
end

# Salvar configuração atualizada
config.update!(value: updated_features)

puts '✅ Funcionalidades habilitadas por padrão:'
features_to_enable.each do |feature_name|
  feature = updated_features.find { |f| f['name'] == feature_name }
  if feature && feature['enabled']
    puts \"   ✅ #{feature['display_name'] || feature_name}\"
  else
    puts \"   ❌ #{feature_name} (não encontrada)\"
  end
end

puts
puts '📋 Resumo das configurações:'
enabled_count = updated_features.count { |f| f['enabled'] }
total_count = updated_features.size
puts \"   Total de features: #{total_count}\"
puts \"   Features habilitadas: #{enabled_count}\"
puts \"   Features desabilitadas: #{total_count - enabled_count}\"

# Limpar cache
GlobalConfig.clear_cache
puts '🗑️  Cache de configuração limpo'
"

print_status "Habilitando funcionalidades para contas existentes..."

# Habilitar funcionalidades para contas existentes
docker exec -i $CONTAINER_ID bundle exec rails runner "
puts '🔧 Habilitando funcionalidades para contas existentes...'

features_to_enable = [
  'whatsapp_campaign',
  'whatsapp_embedded_signup',
  'captain_integration'
]

Account.find_each do |account|
  puts \"Processando conta: #{account.name} (ID: #{account.id})\"
  
  features_enabled = []
  features_to_enable.each do |feature_name|
    unless account.feature_enabled?(feature_name)
      account.enable_features(feature_name)
      features_enabled << feature_name
    end
  end
  
  if features_enabled.any?
    account.save!
    puts \"   ✅ Habilitadas: #{features_enabled.join(', ')}\"
  else
    puts \"   ℹ️  Todas as funcionalidades já estavam habilitadas\"
  end
end

puts '✅ Processamento de contas existentes concluído!'
"

print_status "Verificando configuração final..."

# Verificar configuração final
docker exec -i $CONTAINER_ID bundle exec rails runner "
puts '🔍 Verificando configuração final...'

config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
features_to_check = ['whatsapp_campaign', 'whatsapp_embedded_signup', 'captain_integration']

puts '📋 Status das funcionalidades padrão:'
features_to_check.each do |feature_name|
  feature = config.value.find { |f| f['name'] == feature_name }
  if feature
    status = feature['enabled'] ? '✅ HABILITADA' : '❌ DESABILITADA'
    puts \"   #{feature['display_name'] || feature_name}: #{status}\"
  else
    puts \"   #{feature_name}: ❌ NÃO ENCONTRADA\"
  end
end

puts
puts '🔍 Testando com uma conta existente:'
account = Account.first
if account
  puts \"Conta de teste: #{account.name}\"
  features_to_check.each do |feature_name|
    enabled = account.feature_enabled?(feature_name)
    status = enabled ? '✅ HABILITADA' : '❌ DESABILITADA'
    puts \"   #{feature_name}: #{status}\"
  end
else
  puts '❌ Nenhuma conta encontrada para teste'
end
"

print_success "Configuração concluída!"
echo
print_status "📋 Resumo:"
echo "   ✅ WhatsApp Campaign habilitada por padrão"
echo "   ✅ WhatsApp Embedded Signup habilitada por padrão"
echo "   ✅ Captain habilitada por padrão"
echo "   ✅ Contas existentes atualizadas"
echo
print_status "🎯 Próximas contas criadas terão essas funcionalidades habilitadas automaticamente!"
