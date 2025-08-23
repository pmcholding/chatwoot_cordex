#!/bin/bash

# Hotfix Evolution API Integration Script - Complete Version
# Este script instala a implementação Evolution API e executa todas as configurações necessárias

set -e

echo "=== Hotfix Evolution API Integration - Complete ==="
echo "Iniciando instalação completa da integração Evolution API..."

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

# Patch Settings.vue to show WhatsApp QR tab on API inboxes even if the branch lacks the UI wiring
patch_settings_vue() {
  SETTINGS_VUE="app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue"
  echo "Verificando/patching Settings.vue para aba WhatsApp QR Code..."
  if [ ! -f "$SETTINGS_VUE" ]; then
    echo "⚠️  $SETTINGS_VUE não encontrado; pulando patch de UI"
    return 0
  fi

  # 1) Ensure import of WhatsAppQRCode component
  if ! grep -q "import WhatsAppQRCode from './components/WhatsAppQRCode.vue'" "$SETTINGS_VUE"; then
    echo "• Inserindo import WhatsAppQRCode"
    # Insert just before the first export default occurrence
    sed -i "0,/export default/{/export default/s//import WhatsAppQRCode from '\.\/components\/WhatsAppQRCode.vue';\nexport default/}" "$SETTINGS_VUE" || true
  else
    echo "• Import já presente"
  fi

  # 2) Ensure component registration inside components: { ... }
  if grep -q "components:\s*{" "$SETTINGS_VUE"; then
    if ! grep -q "\bWhatsAppQRCode\b" "$SETTINGS_VUE"; then
      echo "• Registrando componente WhatsAppQRCode no bloco components"
      # Add after the first components: { occurrence
      sed -i "/components\s*{/a \\    WhatsAppQRCode," "$SETTINGS_VUE" || true
    else
      echo "• WhatsAppQRCode já registrado em components"
    fi
  else
    echo "⚠️  Bloco components não encontrado; seguindo"
  fi

  # 3) Ensure tabs() contains whatsappQRCode for API inboxes
  if ! grep -q "key:\s*'whatsappQRCode'" "$SETTINGS_VUE"; then
    echo "• Inserindo tab whatsappQRCode para isAPIInbox"
    awk '
      BEGIN{inserted=0}
      /let[ ]+visibleToAllChannelTabs[ ]*=\[/ && !inserted{
        print; print "        // Add WhatsApp QR Code tab for API channels";
        print "        if (this.isAPIInbox) {";
        print "          visibleToAllChannelTabs = [";
        print "            ...visibleToAllChannelTabs,";
        print "            { key: \"whatsappQRCode\", name: this.$t(\"INBOX_MGMT.TABS.WHATSAPP_QR_CODE\") },";
        print "          ];";
        print "        }";
        inserted=1; next
      }
      {print}
    ' "$SETTINGS_VUE" > "$SETTINGS_VUE.tmp" && mv "$SETTINGS_VUE.tmp" "$SETTINGS_VUE" || true
  else
    echo "• Tab whatsappQRCode já presente"
  fi

  # 4) Ensure template block for selectedTabKey === 'whatsappQRCode'
  if ! grep -q "selectedTabKey === 'whatsappQRCode'" "$SETTINGS_VUE"; then
    echo "• Inserindo bloco de template do WhatsAppQRCode antes de configuration"
    sed -i "/<div v-if=\"selectedTabKey === 'configuration'\">/i \
      <div v-if=\"selectedTabKey === 'whatsappQRCode'\">\n        <WhatsAppQRCode :inbox=\"inbox\" />\n      </div>\n" "$SETTINGS_VUE" || true
  else
    echo "• Bloco de template já presente"
  fi

  echo "✓ Patch de Settings.vue concluído"
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


# Apply Settings.vue UI patch to ensure the tab is visible across branches
patch_settings_vue

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

# Executar bundle install
echo "Executando bundle install..."
if command -v bundle >/dev/null 2>&1; then
    bundle install
    echo "✓ Dependências instaladas com sucesso"
else
    echo "⚠️  Bundle não encontrado. Execute 'bundle install' manualmente."
fi

# Executar pnpm install se necessário (opcional)
if [ -f "package.json" ] && command -v pnpm >/dev/null 2>&1; then
    echo "Executando pnpm install..."
    pnpm install
    echo "✓ Dependências JavaScript instaladas"
else
    echo "ℹ️  pnpm não encontrado ou package.json não existe. Pule se não precisar."
fi

echo ""
echo "🎉 === Instalação Concluída com Sucesso! ==="
echo ""
echo "📋 Resumo:"
echo "• Backup criado em: $BACKUP_DIR"
echo "• Arquivos Evolution API baixados e instalados"
echo "• Rotas configuradas"
echo "• Dependências instaladas automaticamente"
echo "• Pronto para usar!"
echo ""
echo "🚀 Como usar:"
echo "1. Acesse: http://localhost:3000/app/accounts/1/settings/inboxes/32"
echo "2. Vá para a aba 'WhatsApp QR Code' (deve aparecer automaticamente)"
echo "3. Configure sua instância Evolution"
echo ""
echo "🔧 Configuração de ambiente (opcional para teste completo):"
echo "• EVOLUTION_API_URL_V2 - URL da Evolution API"
echo "• EVOLUTION_API_KEY - Chave da Evolution API"
echo "• FRONTEND_URL - URL do Chatwoot"
echo "• CHATWOOT_TOKEN - Token de usuário"
echo ""
echo "🔄 Para reverter:"
echo "• Execute: cp $BACKUP_DIR/*.backup para os arquivos originais"
echo ""
echo "✅ A aba 'WhatsApp QR Code' já deve estar visível nas configurações de inboxes API!"

# Limpar arquivos temporários automaticamente após sucesso
echo ""
echo "Limpando arquivos temporários..."
rm -rf "$TEMP_DIR"
echo "✓ Arquivos temporários removidos"

echo ""
echo "🎯 Comando de teste rápido:"
echo "   Acesse: http://localhost:3000/app/accounts/1/settings/inboxes/32"
echo "   A aba 'WhatsApp QR Code' deve estar disponível!"