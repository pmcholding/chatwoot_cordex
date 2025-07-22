#!/bin/bash

# Script para parar ambiente de desenvolvimento local

echo "🛑 Parando ambiente de desenvolvimento local..."

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

# Parar Sidekiq
print_status "Parando Sidekiq..."
pkill -f sidekiq || true

# Parar Rails server
print_status "Parando Rails server..."
pkill -f "rails server" || true
pkill -f "puma" || true

# Parar processos Node.js relacionados
print_status "Parando processos Node.js..."
pkill -f "webpack" || true
pkill -f "node.*chatwoot" || true

print_success "Ambiente de desenvolvimento parado!"

echo
print_status "📋 Processos parados:"
echo "   ✅ Sidekiq"
echo "   ✅ Rails server"
echo "   ✅ Webpack (se estava rodando)"
echo
print_status "🔧 Para reiniciar:"
echo "   ./start-local-dev.sh"
