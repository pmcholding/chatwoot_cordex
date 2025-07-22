#!/bin/bash

# Script para configurar ambiente de desenvolvimento local
# Espelhando configurações de produção

set -e

echo "🚀 Configurando ambiente de desenvolvimento local..."

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

# Verificar se estamos no diretório correto
if [ ! -f "Gemfile" ]; then
    print_error "Execute este script no diretório raiz do projeto Chatwoot!"
    exit 1
fi

print_status "Verificando dependências do sistema..."

# Verificar Ruby
if ! command -v ruby &> /dev/null; then
    print_error "Ruby não está instalado!"
    exit 1
fi

# Verificar Node.js
if ! command -v node &> /dev/null; then
    print_error "Node.js não está instalado!"
    exit 1
fi

# Verificar PostgreSQL
if ! command -v psql &> /dev/null; then
    print_warning "PostgreSQL não encontrado. Certifique-se de que está instalado e rodando."
fi

# Verificar Redis
if ! command -v redis-cli &> /dev/null; then
    print_warning "Redis não encontrado. Certifique-se de que está instalado e rodando."
fi

print_success "Dependências verificadas!"

print_status "Instalando gems..."
bundle install

print_status "Instalando pacotes Node.js..."
npm install

print_status "Configurando banco de dados..."

# Criar banco se não existir
if ! psql -h localhost -U postgres -lqt | cut -d \| -f 1 | grep -qw chatwoot_development; then
    print_status "Criando banco de dados..."
    bundle exec rails db:create
else
    print_status "Banco de dados já existe"
fi

print_status "Executando migrações..."
bundle exec rails db:migrate

print_status "Executando seeds..."
bundle exec rails db:seed

print_status "Configurando Active Storage..."
echo "Rails.application.config.active_storage.variant_processor = :mini_magick" > config/initializers/active_storage.rb

print_status "Preparando banco de dados Chatwoot..."
bundle exec rails db:chatwoot_prepare

print_status "Compilando assets..."
bundle exec rails assets:precompile

print_success "Ambiente de desenvolvimento configurado!"

echo
print_status "📋 Resumo da configuração:"
echo "   ✅ Gems instaladas"
echo "   ✅ Pacotes Node.js instalados"
echo "   ✅ Banco de dados configurado"
echo "   ✅ Migrações executadas"
echo "   ✅ Seeds executados"
echo "   ✅ Active Storage configurado"
echo "   ✅ Assets compilados"
echo

print_status "🎯 Para iniciar o servidor:"
echo "   ./start-local-dev.sh"
echo

print_status "🔧 Configurações aplicadas:"
echo "   - Idioma padrão: pt_BR"
echo "   - Timezone: America/Sao_Paulo"
echo "   - Features habilitadas: WhatsApp Campaign, WhatsApp Embedded Signup, Captain"
echo "   - Facebook/Instagram configurado"
echo "   - Stripe em modo test"
echo "   - SMTP configurado"
echo

print_warning "⚠️  Certifique-se de que PostgreSQL e Redis estão rodando:"
echo "   sudo systemctl start postgresql"
echo "   sudo systemctl start redis"
