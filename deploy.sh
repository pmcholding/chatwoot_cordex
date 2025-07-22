#!/bin/bash

# Script de Deploy do Chatwoot Cordex ARM64
# Versão com todas as funcionalidades customizadas

set -e

echo "🚀 Iniciando deploy do Chatwoot Cordex ARM64..."

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir mensagens coloridas
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

# Verificar se Docker está instalado
if ! command -v docker &> /dev/null; then
    print_error "Docker não está instalado. Instale o Docker primeiro."
    exit 1
fi

# Verificar se Docker Compose está instalado
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose não está instalado. Instale o Docker Compose primeiro."
    exit 1
fi

# Verificar se arquivo .env.production existe
if [ ! -f ".env.production" ]; then
    print_warning "Arquivo .env.production não encontrado."
    print_status "Copiando .env.production.example para .env.production..."
    cp .env.production.example .env.production
    print_warning "IMPORTANTE: Edite o arquivo .env.production com suas configurações antes de continuar!"
    print_warning "Especialmente as configurações do Stripe, banco de dados e email."
    echo ""
    read -p "Pressione Enter após configurar o arquivo .env.production..."
fi

# Verificar configurações críticas
print_status "Verificando configurações críticas..."

# Verificar SECRET_KEY_BASE
if grep -q "SUBSTITUA_POR_UMA_CHAVE_SEGURA" .env.production; then
    print_error "SECRET_KEY_BASE não foi configurado!"
    print_status "Gerando SECRET_KEY_BASE automaticamente..."
    SECRET_KEY=$(openssl rand -hex 64)
    sed -i "s/SECRET_KEY_BASE=SUBSTITUA_POR_UMA_CHAVE_SEGURA_DE_64_CARACTERES/SECRET_KEY_BASE=$SECRET_KEY/" .env.production
    print_success "SECRET_KEY_BASE gerado e configurado."
fi

# Verificar configurações do Stripe
if grep -q "SUA_CHAVE_SECRETA_AQUI" .env.production; then
    print_error "Configurações do Stripe não foram definidas!"
    print_warning "Configure STRIPE_SECRET_KEY e STRIPE_WEBHOOK_SECRET no arquivo .env.production"
    exit 1
fi

print_success "Configurações verificadas!"

# Pull da imagem
print_status "Fazendo pull da imagem feraug/chatwoot-cordex:latest..."
docker pull feraug/chatwoot-cordex:latest

# Parar containers existentes
print_status "Parando containers existentes..."
docker-compose -f docker-compose.cloud.yml down || true

# Iniciar serviços
print_status "Iniciando serviços..."
docker-compose -f docker-compose.cloud.yml up -d

# Aguardar serviços iniciarem
print_status "Aguardando serviços iniciarem..."
sleep 10

# Verificar se PostgreSQL está rodando
print_status "Verificando PostgreSQL..."
if docker-compose -f docker-compose.cloud.yml exec postgres pg_isready -U chatwoot; then
    print_success "PostgreSQL está rodando!"
else
    print_error "PostgreSQL não está respondendo!"
    exit 1
fi

# Verificar se Redis está rodando
print_status "Verificando Redis..."
if docker-compose -f docker-compose.cloud.yml exec redis redis-cli ping | grep -q PONG; then
    print_success "Redis está rodando!"
else
    print_error "Redis não está respondendo!"
    exit 1
fi

# Executar migrações do banco
print_status "Executando migrações do banco de dados..."
docker-compose -f docker-compose.cloud.yml exec napscloud bundle exec rails db:chatwoot_prepare

# Verificar se a aplicação está rodando
print_status "Verificando se a aplicação está rodando..."
sleep 5

if curl -f http://localhost:3000/api/v1/accounts/status > /dev/null 2>&1; then
    print_success "Aplicação está rodando!"
else
    print_warning "Aplicação pode estar ainda inicializando..."
fi

echo ""
print_success "🎉 Deploy concluído com sucesso!"
echo ""
print_status "📋 Informações do deploy:"
echo "  • Imagem: feraug/chatwoot-cordex:latest"
echo "  • Arquitetura: ARM64"
echo "  • Porta: 3000"
echo "  • URL: http://localhost:3000"
echo ""
print_status "🔧 Próximos passos:"
echo "  1. Configure seu domínio/proxy reverso"
echo "  2. Configure SSL/HTTPS"
echo "  3. Configure backup do banco de dados"
echo "  4. Teste as funcionalidades do Stripe"
echo ""
print_status "📊 Para monitorar os logs:"
echo "  docker-compose -f docker-compose.cloud.yml logs -f"
echo ""
print_status "🛑 Para parar os serviços:"
echo "  docker-compose -f docker-compose.cloud.yml down"
echo ""
print_success "✅ Chatwoot Cordex está pronto para uso!"
