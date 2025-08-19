#!/bin/bash

# Script para build da imagem Docker AMD64 "napscloud"
# Usando Docker Cloud Builder

set -e

echo "🚀 Iniciando build da imagem Docker AMD64 'napscloud' no Docker Cloud..."

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

# Fazer o build da imagem AMD64 no Docker Cloud
echo "🔨 Fazendo build da imagem AMD64 no Docker Cloud..."
docker buildx build \
    --platform linux/amd64 \
    --file docker/Dockerfile \
    --tag feraugaussie/cordex:latest \
    --tag feraugaussie/cordex:$(git rev-parse --short HEAD) \
    --push \
    .

echo "✅ Build concluído com sucesso no Docker Cloud!"
echo "☁️ Imagem AMD64 foi construída e enviada para feraugaussie/cordex"
echo ""
echo "📋 Tags criadas:"
echo "  - feraugaussie/cordex:latest"
echo "  - feraugaussie/cordex:$(git rev-parse --short HEAD)"
echo ""
echo "🎯 Para usar a imagem:"
echo "docker pull feraugaussie/cordex:latest"
echo "docker run -p 3000:3000 feraugaussie/cordex:latest"
echo ""
echo "🐳 Imagem disponível em: https://hub.docker.com/r/feraugaussie/cordex"

