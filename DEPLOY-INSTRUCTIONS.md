# 🚀 IMAGEM DOCKER ARM64 "NAPSCLOUD" - INSTRUÇÕES DE DEPLOY

## ✅ **IMAGEM CRIADA COM SUCESSO!**

A imagem Docker ARM64 `napscloud:latest` foi construída com sucesso no Docker Cloud Builder com todas as funcionalidades da branch `feature/new-changes`.

### 📋 **INFORMAÇÕES DA IMAGEM:**

- **Nome:** `feraug/chatwoot-cordex:latest`
- **Arquitetura:** `linux/arm64`
- **Commit:** Mais recente (feature/new-changes)
- **Webhook Stripe:** ✅ **CORRIGIDO** - `/enterprise/webhooks/stripe`
- **Sistema de Billing:** ✅ **FUNCIONANDO** - Metadata e trial automático

## 🎯 **FUNCIONALIDADES INCLUÍDAS:**

### ✅ **Traduções Atualizadas:**
- **Português:** "Captain" → "Agente IA"
- **Inglês:** "Captain" → "AI Agent"
- Sidebar, Settings, Integrações todas atualizadas

### ✅ **Funcionalidades Premium Habilitadas por Padrão:**
- `captain_integration` (Agente IA)
- `whatsapp_campaign` (Campanhas WhatsApp)
- `whatsapp_embedded_signup` (Cadastro WhatsApp)
- `shopify_integration` (Integração Shopify)
- `sla` (Acordos de Nível de Serviço)
- `disable_branding` (Remover Branding)
- `custom_roles` (Funções Personalizadas)

### ✅ **Sistema de Trial Automático:**
- Trial de 7 dias automático
- Integração com Stripe
- Portal de cobrança Stripe

## 🐳 **COMO USAR NO SEU SERVIDOR ARM64:**

### 1. **Pull da Imagem:**
```bash
# A imagem foi construída no Docker Cloud
# Você pode fazer pull diretamente:
docker pull napscloud:latest
```

### 2. **Executar com Docker Compose:**
```bash
# Use o arquivo docker-compose.cloud.yml incluído
docker-compose -f docker-compose.cloud.yml up -d
```

### 3. **Executar Manualmente:**
```bash
# Executar a imagem diretamente
docker run -d \
  --name napscloud \
  -p 3000:3000 \
  -e RAILS_ENV=production \
  -e SECRET_KEY_BASE=your_secret_key_here \
  -e DATABASE_URL=postgresql://user:pass@host:5432/chatwoot_production \
  -e REDIS_URL=redis://redis:6379 \
  napscloud:latest
```

## 🔧 **CONFIGURAÇÃO NECESSÁRIA:**

### **🔑 Variáveis de Ambiente OBRIGATÓRIAS:**

#### **1. Configurações Básicas:**
```bash
# Ambiente Rails
RAILS_ENV=production

# Chave secreta (use: openssl rand -hex 64)
SECRET_KEY_BASE=your_64_character_secret_key_here

# URL do frontend
FRONTEND_URL=https://your-domain.com
```

#### **2. Banco de Dados PostgreSQL:**
```bash
POSTGRES_HOST=your-postgres-host
POSTGRES_USERNAME=chatwoot_user
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DATABASE=chatwoot_production
# Ou use uma URL completa:
# DATABASE_URL=postgresql://user:pass@host:5432/chatwoot_production
```

#### **3. Redis:**
```bash
REDIS_URL=redis://your-redis-host:6379
# Se Redis tem senha:
REDIS_PASSWORD=your_redis_password
```

#### **4. 💳 STRIPE (OBRIGATÓRIO para funcionalidades de cobrança):**
```bash
# Chave secreta do Stripe (sk_live_... para produção)
STRIPE_SECRET_KEY=sk_live_your_stripe_secret_key

# Webhook secret do Stripe (whsec_...)
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
```

#### **5. Email SMTP:**
```bash
# Email remetente
MAILER_SENDER_EMAIL=noreply@your-domain.com

# Configurações SMTP
SMTP_ADDRESS=your-smtp-server.com
SMTP_PORT=587
SMTP_USERNAME=your-smtp-username
SMTP_PASSWORD=your-smtp-password
SMTP_AUTHENTICATION=login
SMTP_ENABLE_STARTTLS_AUTO=true
SMTP_DOMAIN=your-domain.com
```

### **⚙️ Variáveis de Ambiente OPCIONAIS:**

#### **Segurança e Performance:**
```bash
FORCE_SSL=true
RAILS_LOG_TO_STDOUT=true
RAILS_MAX_THREADS=5
SIDEKIQ_CONCURRENCY=10
```

#### **Armazenamento de Arquivos (AWS S3):**
```bash
# Para upload de arquivos na nuvem
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=us-east-1
S3_BUCKET_NAME=your-bucket-name
DIRECT_UPLOADS_ENABLED=true
```

#### **Notificações Push:**
```bash
# Para notificações web push
VAPID_PUBLIC_KEY=your_vapid_public_key
VAPID_PRIVATE_KEY=your_vapid_private_key

# Para apps mobile
FCM_SERVER_KEY=your_fcm_server_key
```

#### **Integrações Opcionais:**
```bash
# OpenAI para IA
OPENAI_API_KEY=your_openai_api_key

# Microsoft Azure
AZURE_APP_ID=your_azure_app_id
AZURE_APP_SECRET=your_azure_app_secret

# hCaptcha
HCAPTCHA_SITE_KEY=your_hcaptcha_site_key
HCAPTCHA_SECRET_KEY=your_hcaptcha_secret_key
```

## 💳 **CONFIGURAÇÃO DETALHADA DO STRIPE:**

### **1. Criar Conta Stripe:**
1. Acesse https://stripe.com e crie uma conta
2. Ative o modo de produção
3. Configure os produtos e preços

### **2. Obter Chaves da API:**
```bash
# No Dashboard do Stripe > Developers > API keys
STRIPE_SECRET_KEY=sk_live_...  # Chave secreta de produção
```

### **3. Configurar Webhooks:**
1. Vá para Developers > Webhooks
2. Adicione endpoint: `https://your-domain.com/webhooks/stripe`
3. Selecione eventos:
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
4. Copie o signing secret:
```bash
STRIPE_WEBHOOK_SECRET=whsec_...
```

### **4. Produtos Configurados (já incluídos na imagem):**
- **Cordex Starter**: 5 agentes, 100 documentos IA, 500 respostas IA
- **Cordex Professional**: 15 agentes, 300 documentos IA, 1000 respostas IA
- **Cordex Enterprise**: 25 agentes, 500 documentos IA, 2000 respostas IA

### **5. Trial Automático:**
- Sistema de 7 dias de trial já configurado
- Ativação automática ao criar conta
- Cobrança automática após trial

## 📦 **ARQUIVOS INCLUÍDOS:**

- `docker-compose.cloud.yml` - Configuração completa com PostgreSQL e Redis
- `build-arm.sh` - Script usado para build
- `DEPLOY-INSTRUCTIONS.md` - Este arquivo

## 🎉 **PRONTO PARA PRODUÇÃO!**

A imagem `napscloud:latest` está pronta para ser executada no seu servidor ARM64 com todas as funcionalidades customizadas implementadas!

### **Próximos Passos:**
1. Configure as variáveis de ambiente
2. Execute a imagem no seu servidor
3. Acesse via navegador na porta 3000
4. Teste as funcionalidades do "Agente IA"
5. Verifique as funcionalidades premium habilitadas

**🚀 Sua versão customizada do Chatwoot está pronta para uso!**
