#!/bin/bash

# Hotfix Evolution API Integration Script - Local Version
# Este script instala a implementação Evolution API no ambiente local

set -e

echo "=== Hotfix Evolution API Integration - Local ===" 
echo "Iniciando instalação da integração Evolution API localmente..."

# Variáveis de configuração
BACKUP_DIR="/tmp/chatwoot-evolution-backup-$(date +%Y%m%d_%H%M%S)"
TEMP_DIR="/tmp/evolution-files-$(date +%Y%m%d_%H%M%S)"
GITHUB_BASE_URL="https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821"

echo "Backup será criado em: $BACKUP_DIR"
echo "GitHub base URL: $GITHUB_BASE_URL"
echo "Temp directory: $TEMP_DIR"

# Função para baixar arquivo do GitHub
download_file() {
    local file_path="$1"
    local url="${GITHUB_BASE_URL}/${file_path}"
    local dest="${TEMP_DIR}/${file_path}"
    
    echo "Baixando $file_path..."
    mkdir -p "$(dirname "$dest")"
    
    if curl -L -f -s -o "$dest" "$url"; then
        echo "✓ $file_path baixado com sucesso"
        return 0
    else
        echo "⚠️  Falha ao baixar $file_path"
        return 1
    fi
}

# Função para adicionar métodos Evolution ao modelo Channel::Api
add_evolution_methods_to_model() {
    echo "Verificando se métodos Evolution já existem no modelo Channel::Api..."
    
    if grep -q 'evolution_webhook_configured?' app/models/channel/api.rb 2>/dev/null; then
        echo "✓ Métodos Evolution já existem no modelo"
        return 0
    fi
    
    echo "Adicionando métodos Evolution ao modelo Channel::Api..."
    
    # Baixar arquivo com métodos Evolution
    local methods_url="${GITHUB_BASE_URL}/evolution-methods.rb"
    local methods_file="${TEMP_DIR}/evolution-methods.rb"
    
    if curl -L -f -s -o "$methods_file" "$methods_url"; then
        echo "✓ Métodos Evolution baixados"
    else
        echo "⚠️  Falha ao baixar métodos Evolution, criando localmente..."
        cat > "$methods_file" << 'EVOLUTION_METHODS'
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
EVOLUTION_METHODS
    fi
    
    # Fazer backup do modelo original
    cp app/models/channel/api.rb app/models/channel/api.rb.backup
    
    # Inserir métodos Evolution antes do 'private' ou antes do último 'end'
    if grep -q 'private' app/models/channel/api.rb; then
        sed -i '/private/i\\n  # Evolution API methods added by hotfix' app/models/channel/api.rb
        sed -i '/Evolution API methods added by hotfix/r '"$methods_file" app/models/channel/api.rb
    else
        # Se não tem 'private', inserir antes do último 'end'
        sed -i '$i\\n  # Evolution API methods added by hotfix' app/models/channel/api.rb
        sed -i '/Evolution API methods added by hotfix/r '"$methods_file" app/models/channel/api.rb
    fi
    
    echo "✓ Métodos Evolution adicionados ao modelo Channel::Api"
}

# Criar backup dos arquivos que serão modificados
echo "Criando backup dos arquivos existentes..."
mkdir -p "$BACKUP_DIR"

# Lista dos arquivos Evolution
declare -A EVOLUTION_FILES=(
    ["app/controllers/api/v1/accounts/inboxes/evolution_whatsapp_controller.rb"]="app/controllers/api/v1/accounts/inboxes/evolution_whatsapp_controller.rb"
    ["app/controllers/api/v1/webhooks/evolution_controller.rb"]="app/controllers/api/v1/webhooks/evolution_controller.rb"
    ["app/services/evolution_api_service.rb"]="app/services/evolution_api_service.rb"
    ["app/javascript/dashboard/api/evolutionWhatsapp.js"]="app/javascript/dashboard/api/evolutionWhatsapp.js"
    ["app/javascript/dashboard/routes/dashboard/settings/inbox/channels/EvolutionWhatsapp.vue"]="app/javascript/dashboard/routes/dashboard/settings/inbox/channels/EvolutionWhatsapp.vue"
    ["app/javascript/dashboard/routes/dashboard/settings/inbox/components/WhatsAppQRCode.vue"]="app/javascript/dashboard/routes/dashboard/settings/inbox/components/WhatsAppQRCode.vue"
    ["app/javascript/dashboard/i18n/locale/en/inboxMgmt.json"]="app/javascript/dashboard/i18n/locale/en/inboxMgmt.json"
    ["app/javascript/dashboard/i18n/locale/pt_BR/inboxMgmt.json"]="app/javascript/dashboard/i18n/locale/pt_BR/inboxMgmt.json"
)

# Criar diretório temporário para downloads
mkdir -p "$TEMP_DIR"

# Fazer backup dos arquivos existentes
echo "Fazendo backup dos arquivos existentes..."
for file in "${!EVOLUTION_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "Fazendo backup de $file..."
        cp "$file" "$BACKUP_DIR/$(basename $file).backup"
    fi
done

echo "✓ Backup concluído em $BACKUP_DIR"

# Baixar arquivos Evolution do GitHub
echo "Baixando arquivos da integração Evolution do GitHub..."
download_success=true

for file in "${!EVOLUTION_FILES[@]}"; do
    if ! download_file "$file"; then
        download_success=false
    fi
done

if [ "$download_success" != "true" ]; then
    echo "❌ Erro: Alguns arquivos falharam ao baixar. Abortando instalação."
    exit 1
fi

echo "✓ Todos os arquivos baixados com sucesso"

# Copiar arquivos baixados para o projeto
echo "Copiando arquivos baixados para o projeto..."

for file in "${!EVOLUTION_FILES[@]}"; do
    local_file="${TEMP_DIR}/${file}"
    if [ -f "$local_file" ]; then
        echo "Copiando $file..."
        mkdir -p "$(dirname "$file")"
        cp "$local_file" "$file"
    else
        echo "⚠️  Arquivo baixado $file não encontrado"
    fi
done

echo "✓ Arquivos copiados com sucesso"

# Adicionar métodos Evolution ao modelo Channel::Api (sem sobrescrever)
add_evolution_methods_to_model

# Função para adicionar rotas Evolution ao routes.rb
add_evolution_routes() {
    echo "Verificando rotas da Evolution API..."
    
    if grep -q 'evolution_whatsapp' config/routes.rb 2>/dev/null; then
        echo "✓ Rotas Evolution já existem"
        return 0
    fi
    
    echo "Adicionando rotas da Evolution API..."
    
    # Baixar arquivo com rotas Evolution
    local routes_url="${GITHUB_BASE_URL}/add-evolution-routes.rb"
    local routes_file="${TEMP_DIR}/add-evolution-routes.rb"
    
    if curl -L -f -s -o "$routes_file" "$routes_url"; then
        echo "✓ Rotas Evolution baixadas"
    else
        echo "⚠️  Falha ao baixar rotas Evolution, criando localmente..."
        cat > "$routes_file" << 'EVOLUTION_ROUTES'
        # Evolution WhatsApp API routes
        resources :evolution_whatsapp, only: [] do
          post :initialize_instance
          get :connection_status
          get :connect_qr_code
          delete :disconnect
          post :connect_with_number
          post :update_settings
          get :webhook_info
          get :instance_settings
        end
EVOLUTION_ROUTES
    fi
    
    # Fazer backup do routes.rb original
    cp config/routes.rb config/routes.rb.backup
    
    # Inserir rotas Evolution após 'resources :inboxes do'
    sed -i '/resources :inboxes do/r '"$routes_file" config/routes.rb
    
    echo "✓ Rotas Evolution adicionadas"
}

# Adicionar rotas se necessário
add_evolution_routes

# Adicionar webhook routes se necessário
if ! grep -q 'evolution' config/routes.rb | grep -q webhook 2>/dev/null; then
    echo "Adicionando rota de webhook..."
    sed -i '/namespace :webhooks do/a\    post "evolution/:instance_name", to: "evolution#process_webhook"' config/routes.rb
    echo "✓ Rota de webhook adicionada"
fi

# Verificar dependências
echo "Verificando dependências..."
if ! grep -q 'httparty' Gemfile 2>/dev/null; then
    echo "Adicionando HTTParty ao Gemfile..."
    echo "gem 'httparty'" >> Gemfile
    echo "✓ HTTParty adicionado ao Gemfile"
fi

echo ""
echo "=== Instalação Concluída ==="
echo ""
echo "📋 Resumo:"
echo "• Backup criado em: $BACKUP_DIR"
echo "• Arquivos Evolution API baixados e instalados"
echo "• Rotas configuradas"
echo "• Dependências adicionadas ao Gemfile"
echo ""
echo "🔧 Próximos passos:"
echo "• Execute: bundle install"
echo "• Execute: pnpm install (se necessário)"
echo "• Configure as variáveis de ambiente:"
echo "  - EVOLUTION_API_URL_V2"
echo "  - EVOLUTION_API_KEY"
echo "  - FRONTEND_URL"
echo "  - CHATWOOT_TOKEN"
echo ""
echo "📖 Para usar:"
echo "1. Acesse Configurações > Caixas de Entrada"
echo "2. Adicione nova caixa de entrada"
echo "3. Selecione 'API'"
echo "4. Vá para aba 'WhatsApp QR Code'"
echo ""
echo "🔄 Para reverter:"
echo "• Execute: cp $BACKUP_DIR/*.backup para os arquivos originais"
echo ""
echo "🧹 Limpeza:"
echo "• Arquivos temporários em: $TEMP_DIR"
echo "• Execute: rm -rf $TEMP_DIR (após confirmar que tudo funcionou)"

# Limpar arquivos temporários automaticamente após sucesso
echo ""
echo "Limpando arquivos temporários..."
rm -rf "$TEMP_DIR"
echo "✓ Arquivos temporários removidos"