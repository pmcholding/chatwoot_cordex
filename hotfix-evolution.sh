#!/bin/bash

# Hotfix Evolution API Integration Script
# Este script instala a implementação Evolution API em outras instâncias do Chatwoot
# via container Docker baixando arquivos diretamente do GitHub

set -e

echo "=== Hotfix Evolution API Integration ==="
echo "Iniciando instalação da integração Evolution API..."

# Variáveis de configuração
CONTAINER_NAME="${CHATWOOT_CONTAINER:-chatwoot}"
BACKUP_DIR="/tmp/chatwoot-evolution-backup-$(date +%Y%m%d_%H%M%S)"
TEMP_DIR="/tmp/evolution-files-$(date +%Y%m%d_%H%M%S)"
GITHUB_BASE_URL="${GITHUB_RAW_URL:-https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821}"

echo "Container alvo: $CONTAINER_NAME"
echo "Backup será criado em: $BACKUP_DIR"
echo "GitHub base URL: $GITHUB_BASE_URL"
echo "Temp directory: $TEMP_DIR"

# Função para executar comandos no container
run_in_container() {
    docker exec -it "$CONTAINER_NAME" bash -c "$1"
}

# Função para copiar arquivo para o container
copy_to_container() {
    local src="$1"
    local dest="$2"
    echo "Copiando $src para $dest no container..."
    docker cp "$src" "$CONTAINER_NAME:$dest"
}

# Função para adicionar métodos Evolution ao modelo Channel::Api
add_evolution_methods_to_model() {
    echo "Verificando se métodos Evolution já existem no modelo Channel::Api..."
    
    if run_in_container "grep -q 'evolution_webhook_configured?' app/models/channel/api.rb"; then
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
    
    # Copiar arquivo de métodos para o container
    copy_to_container "$methods_file" "/tmp/evolution-methods.rb"
    
    # Inserir métodos antes do último 'end' do arquivo
    run_in_container "
        # Fazer backup do modelo original
        cp app/models/channel/api.rb app/models/channel/api.rb.backup
        
        # Inserir métodos Evolution antes do 'private' ou antes do último 'end'
        if grep -q 'private' app/models/channel/api.rb; then
            sed -i '/private/i\\n  # Evolution API methods added by hotfix' app/models/channel/api.rb
            sed -i '/Evolution API methods added by hotfix/r /tmp/evolution-methods.rb' app/models/channel/api.rb
        else
            # Se não tem 'private', inserir antes do último 'end'
            sed -i '\$i\\n  # Evolution API methods added by hotfix' app/models/channel/api.rb
            sed -i '/Evolution API methods added by hotfix/r /tmp/evolution-methods.rb' app/models/channel/api.rb
        fi
        
        # Limpar arquivo temporário
        rm /tmp/evolution-methods.rb
    "
    
    echo "✓ Métodos Evolution adicionados ao modelo Channel::Api"
}

# Verificar se o container existe e está rodando
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "Erro: Container $CONTAINER_NAME não encontrado ou não está rodando"
    exit 1
fi

echo "✓ Container encontrado e rodando"

# Criar backup dos arquivos que serão modificados
echo "Criando backup dos arquivos existentes..."
mkdir -p "$BACKUP_DIR"

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

# Lista dos arquivos Evolution com suas URLs (excluindo modelo api.rb que será tratado separadamente)
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

# Arquivo de configuração que será tratado separadamente
declare -A CONFIG_FILES=(
    ["config/routes.rb"]="config/routes.rb"
)

# Arquivos de spec opcionais
declare -A SPEC_FILES=(
    ["spec/services/evolution_api_service_spec.rb"]="spec/services/evolution_api_service_spec.rb"
    ["spec/models/channel/api_spec.rb"]="spec/models/channel/api_spec.rb"
)

# Criar diretório temporário para downloads
mkdir -p "$TEMP_DIR"

# Fazer backup dos arquivos existentes
echo "Fazendo backup dos arquivos existentes..."
for file in "${!EVOLUTION_FILES[@]}"; do
    if docker exec "$CONTAINER_NAME" test -f "$file" 2>/dev/null; then
        echo "Fazendo backup de $file..."
        docker cp "$CONTAINER_NAME:$file" "$BACKUP_DIR/$(basename $file).backup"
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

# Baixar arquivos de spec opcionalmente
echo "Baixando arquivos de spec (opcionais)..."
for file in "${!SPEC_FILES[@]}"; do
    download_file "$file" || true  # Não falhar se spec não existir
done

if [ "$download_success" != "true" ]; then
    echo "❌ Erro: Alguns arquivos falharam ao baixar. Abortando instalação."
    exit 1
fi

echo "✓ Todos os arquivos baixados com sucesso"

# Copiar arquivos baixados para o container
echo "Copiando arquivos baixados para o container..."

for file in "${!EVOLUTION_FILES[@]}"; do
    local_file="${TEMP_DIR}/${file}"
    if [ -f "$local_file" ]; then
        copy_to_container "$local_file" "/$file"
    else
        echo "⚠️  Arquivo baixado $file não encontrado"
    fi
done

# Copiar spec files se existirem
for file in "${!SPEC_FILES[@]}"; do
    local_file="${TEMP_DIR}/${file}"
    if [ -f "$local_file" ]; then
        copy_to_container "$local_file" "/$file"
    fi
done

echo "✓ Arquivos copiados com sucesso"

# Adicionar métodos Evolution ao modelo Channel::Api (sem sobrescrever)
add_evolution_methods_to_model

# Função para adicionar rotas Evolution ao routes.rb
add_evolution_routes() {
    echo "Verificando rotas da Evolution API..."
    
    if run_in_container "grep -q 'evolution_whatsapp' config/routes.rb"; then
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
    
    # Copiar arquivo de rotas para o container
    copy_to_container "$routes_file" "/tmp/add-evolution-routes.rb"
    
    # Inserir rotas após 'resources :inboxes do'
    run_in_container "
        # Fazer backup do routes.rb original
        cp config/routes.rb config/routes.rb.backup
        
        # Inserir rotas Evolution após 'resources :inboxes do'
        sed -i '/resources :inboxes do/r /tmp/add-evolution-routes.rb' config/routes.rb
        
        # Limpar arquivo temporário
        rm /tmp/add-evolution-routes.rb
    "
    
    echo "✓ Rotas Evolution adicionadas"
}

# Adicionar rotas se necessário
add_evolution_routes

# Adicionar webhook routes se necessário
if ! run_in_container "grep -q 'evolution' config/routes.rb | grep webhook"; then
    echo "Adicionando rota de webhook..."
    run_in_container "sed -i '/namespace :webhooks do/a\\    post \"evolution/:instance_name\", to: \"evolution#process_webhook\"' config/routes.rb"
    echo "✓ Rota de webhook adicionada"
fi

# Instalar dependências se necessário
echo "Verificando dependências..."
if ! run_in_container "grep -q 'httparty' Gemfile"; then
    echo "Adicionando HTTParty ao Gemfile..."
    run_in_container "echo \"gem 'httparty'\" >> Gemfile"
    echo "✓ HTTParty adicionado ao Gemfile"
fi

# Executar bundle install
echo "Executando bundle install..."
run_in_container "bundle install"
echo "✓ Dependências instaladas"

# Recompilar assets se necessário
echo "Recompilando assets..."
run_in_container "bundle exec rails assets:precompile RAILS_ENV=production"
echo "✓ Assets recompilados"

# Reiniciar aplicação
echo "Reiniciando aplicação..."
run_in_container "touch tmp/restart.txt"

# Verificar se a aplicação está funcionando
echo "Aguardando reinicialização..."
sleep 10

if run_in_container "curl -f -s http://localhost:3000/health > /dev/null"; then
    echo "✅ Aplicação reiniciada com sucesso!"
else
    echo "⚠️  Aplicação pode não estar respondendo. Verificar logs."
fi

echo ""
echo "=== Instalação Concluída ==="
echo ""
echo "📋 Resumo:"
echo "• Backup criado em: $BACKUP_DIR"
echo "• Arquivos Evolution API baixados e instalados"
echo "• Rotas configuradas"
echo "• Dependências instaladas"
echo "• Assets recompilados"
echo "• Aplicação reiniciada"
echo ""
echo "🔧 Configuração necessária:"
echo "• Definir EVOLUTION_API_URL no ambiente"
echo "• Definir EVOLUTION_API_KEY no ambiente" 
echo "• Definir FRONTEND_URL no ambiente"
echo "• Configurar tokens de usuário para Evolution API"
echo ""
echo "📖 Para usar:"
echo "1. Acesse Configurações > Caixas de Entrada"
echo "2. Adicione nova caixa de entrada"
echo "3. Selecione 'Evolution WhatsApp'"
echo "4. Configure a instância Evolution"
echo ""
echo "🔄 Para reverter:"
echo "• Execute: docker cp $BACKUP_DIR/arquivo.backup $CONTAINER_NAME:/caminho/arquivo"
echo "• Reinicie o container"
echo ""
echo "🧹 Limpeza:"
echo "• Arquivos temporários em: $TEMP_DIR"
echo "• Execute: rm -rf $TEMP_DIR (após confirmar que tudo funcionou)"
echo ""

# Limpar arquivos temporários automaticamente após sucesso
echo "Limpando arquivos temporários..."
rm -rf "$TEMP_DIR"
echo "✓ Arquivos temporários removidos"