#!/bin/bash

# Script para build da imagem Docker ARM64 "napscloud"
# Usando Docker Cloud Builder

set -e

echo "🚀 Iniciando build da imagem Docker ARM64 'napscloud' no Docker Cloud..."

# Usar o builder Docker Cloud existente
BUILDER_NAME="cloud-feraugaussie-naps2"

echo "☁️ Verificando Docker Cloud Builder..."

# Verificar se o builder existe
if docker buildx ls | grep -q "$BUILDER_NAME"; then
    echo "✅ Builder Docker Cloud encontrado: $BUILDER_NAME"
else
    echo "❌ Builder Docker Cloud não encontrado. Verifique a configuração."
    exit 1
fi

# Usar o builder do Docker Cloud
echo "🔧 Usando builder Docker Cloud..."
docker buildx use "$BUILDER_NAME"

# Fazer o build da imagem ARM64 no Docker Cloud
echo "🔨 Fazendo build da imagem ARM64 no Docker Cloud..."
docker buildx build \
    --platform linux/arm64 \
    --file docker/Dockerfile \
    --tag feraugaussie/cordex:latest \
    --tag feraugaussie/cordex:arm64 \
    --tag feraugaussie/cordex:$(git rev-parse --short HEAD) \
    --tag feraugaussie/cordex:feature-new-changes \
    --push \
    .

echo "✅ Build concluído com sucesso no Docker Cloud!"
echo "☁️ Imagem ARM64 foi construída e enviada para feraugaussie/cordex"
echo ""
echo "📋 Tags criadas:"
echo "  - feraugaussie/cordex:latest"
echo "  - feraugaussie/cordex:arm64"
echo "  - feraugaussie/cordex:$(git rev-parse --short HEAD)"
echo "  - feraugaussie/cordex:feature-new-changes"
echo ""
echo "🔧 Correções incluídas nesta versão:"
echo "  ✅ Webhook do Stripe corrigido (/enterprise/webhooks/stripe)"
echo "  ✅ Processamento de metadata do Stripe corrigido"
echo "  ✅ Sistema de trial automático funcionando"
echo "  ✅ Traduções 'Agente IA' implementadas"
echo ""
echo "🎯 Para usar a imagem:"
echo "docker pull feraugaussie/cordex:latest"
echo "docker run -p 3000:3000 feraugaussie/cordex:latest"
echo ""
echo "🐳 Imagem disponível em: https://hub.docker.com/r/feraugaussie/cordex"
