#!/bin/bash

# Script para iniciar ambiente de desenvolvimento local
# Espelhando configurações de produção

set -e

echo "🚀 Iniciando ambiente de desenvolvimento local..."

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

# Verificar se o arquivo .env.development.local existe
if [ ! -f ".env.development.local" ]; then
    print_error "Arquivo .env.development.local não encontrado!"
    print_status "Execute primeiro: ./setup-local-dev.sh"
    exit 1
fi

print_status "Verificando serviços..."

# Verificar PostgreSQL
if ! pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
    print_error "PostgreSQL não está rodando!"
    print_status "Inicie com: sudo systemctl start postgresql"
    exit 1
fi

# Verificar Redis
if ! redis-cli ping >/dev/null 2>&1; then
    print_error "Redis não está rodando!"
    print_status "Inicie com: sudo systemctl start redis"
    exit 1
fi

print_success "Serviços verificados!"

# Função para cleanup ao sair
cleanup() {
    print_status "Parando processos..."
    jobs -p | xargs -r kill
    exit 0
}

trap cleanup SIGINT SIGTERM

print_status "Configurando Active Storage..."
echo "Rails.application.config.active_storage.variant_processor = :mini_magick" > config/initializers/active_storage.rb

print_status "Executando migrações pendentes..."
bundle exec rails db:migrate

print_status "Iniciando Sidekiq em background..."
bundle exec sidekiq -C config/sidekiq.yml &

print_status "Iniciando servidor Rails..."
echo
print_success "🎉 Ambiente de desenvolvimento iniciado!"
echo
print_status "📋 Informações do ambiente:"
echo "   🌐 URL: http://localhost:3000"
echo "   🗄️  Banco: chatwoot_development"
echo "   🔧 Redis: localhost:6379"
echo "   📧 SMTP: configurado (contato@cordex.ai)"
echo "   💳 Stripe: modo test"
echo "   🌍 Idioma: pt_BR"
echo "   ⏰ Timezone: America/Sao_Paulo"
echo
print_status "🎯 Features habilitadas por padrão:"
echo "   ✅ WhatsApp Campaign"
echo "   ✅ WhatsApp Embedded Signup"
echo "   ✅ Captain Integration"
echo
print_warning "⚠️  Para parar o servidor: Ctrl+C"
echo

# Iniciar servidor Rails
bundle exec rails server -p 3000 -b 0.0.0.0
