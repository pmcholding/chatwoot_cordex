# Ambiente de Desenvolvimento Local

Este documento descreve como configurar e usar o ambiente de desenvolvimento local que espelha exatamente a configuração de produção.

## 🎯 **Objetivo**

Criar um ambiente de desenvolvimento local que seja idêntico à produção, permitindo:
- Desenvolvimento seguro sem afetar produção
- Testes de funcionalidades em ambiente controlado
- Debugging e desenvolvimento de novas features
- Validação de configurações antes do deploy

## 📋 **Pré-requisitos**

### **Sistema Operacional**
- Linux (Ubuntu/Debian recomendado)
- macOS
- Windows com WSL2

### **Dependências Necessárias**
```bash
# Ruby (versão conforme .ruby-version)
rbenv install $(cat .ruby-version)

# Node.js (versão conforme .nvmrc)
nvm install $(cat .nvmrc)

# PostgreSQL
sudo apt install postgresql postgresql-contrib

# Redis
sudo apt install redis-server

# ImageMagick (para Active Storage)
sudo apt install imagemagick

# Yarn
npm install -g yarn
```

## 🚀 **Configuração Inicial**

### **1. Clone e Configure o Projeto**
```bash
git clone https://github.com/pmcholding/chatwoot_cordex.git
cd chatwoot_cordex
git checkout feature/new-changes
```

### **2. Execute o Script de Configuração**
```bash
chmod +x setup-local-dev.sh
./setup-local-dev.sh
```

### **3. Inicie os Serviços do Sistema**
```bash
# PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Redis
sudo systemctl start redis
sudo systemctl enable redis
```

### **4. Inicie o Ambiente de Desenvolvimento**
```bash
chmod +x start-local-dev.sh
./start-local-dev.sh
```

## 🔧 **Configurações Aplicadas**

### **Espelhamento da Produção**
- ✅ **Idioma padrão:** pt_BR
- ✅ **Timezone:** America/Sao_Paulo
- ✅ **Features habilitadas:** WhatsApp Campaign, WhatsApp Embedded Signup, Captain
- ✅ **Facebook/Instagram:** Configurado com tokens de produção
- ✅ **SMTP:** Configurado com servidor de produção
- ✅ **Stripe:** Modo test (seguro para desenvolvimento)
- ✅ **Redis:** Cache e jobs como produção
- ✅ **Active Storage:** Armazenamento local

### **Diferenças Seguras para Desenvolvimento**
- 🔒 **SECRET_KEY_BASE:** Chave específica para desenvolvimento
- 🔒 **STRIPE_SECRET_KEY:** Chave de test do Stripe
- 🔒 **FRONTEND_URL:** http://localhost:3000
- 🔒 **FORCE_SSL:** Desabilitado
- 🔒 **RAILS_ENV:** development

## 📱 **Acesso ao Sistema**

### **URLs Principais**
- **Frontend:** http://localhost:3000
- **Admin:** http://localhost:3000/super_admin
- **API:** http://localhost:3000/api/v1

### **Credenciais Padrão**
Após executar `rails db:seed`:
- **Email:** admin@chatwoot.com
- **Senha:** 123456

## 🛠 **Scripts Disponíveis**

### **Configuração**
```bash
./setup-local-dev.sh    # Configurar ambiente inicial
```

### **Execução**
```bash
./start-local-dev.sh    # Iniciar ambiente
./stop-local-dev.sh     # Parar ambiente
```

### **Desenvolvimento**
```bash
# Rails console
bundle exec rails console

# Sidekiq web interface
bundle exec sidekiq -C config/sidekiq.yml

# Testes
bundle exec rspec

# Rubocop
bundle exec rubocop
```

## 🔍 **Debugging e Logs**

### **Logs do Rails**
```bash
tail -f log/development.log
```

### **Logs do Sidekiq**
```bash
tail -f log/sidekiq.log
```

### **Redis CLI**
```bash
redis-cli
```

### **PostgreSQL**
```bash
psql -h localhost -U postgres -d chatwoot_development
```

## 🧪 **Testes de Funcionalidades**

### **WhatsApp Campaign**
1. Acesse Configurações > Integrações
2. Configure WhatsApp Business
3. Teste criação de campanhas

### **Captain Integration**
1. Acesse Configurações > Integrações
2. Configure Captain
3. Teste respostas automáticas

### **Stripe Billing**
1. Acesse Configurações > Billing
2. Teste com cartões de test do Stripe
3. Verifique webhooks em http://localhost:3000/enterprise/webhooks/stripe

## ⚠️ **Troubleshooting**

### **Erro de Conexão com PostgreSQL**
```bash
sudo systemctl status postgresql
sudo systemctl restart postgresql
```

### **Erro de Conexão com Redis**
```bash
sudo systemctl status redis
sudo systemctl restart redis
```

### **Erro de Gems**
```bash
bundle install
```

### **Erro de Assets**
```bash
bundle exec rails assets:precompile
```

### **Erro de Migrações**
```bash
bundle exec rails db:migrate
bundle exec rails db:chatwoot_prepare
```

## 📝 **Desenvolvimento de Features**

### **Workflow Recomendado**
1. Desenvolva no ambiente local
2. Teste todas as funcionalidades
3. Execute testes automatizados
4. Faça commit das mudanças
5. Teste em staging (se disponível)
6. Deploy para produção

### **Sincronização com Produção**
- Use as mesmas configurações de features
- Teste com dados similares à produção
- Valide integrações externas
- Verifique performance

## 🎯 **Próximos Passos**

Após configurar o ambiente local:
1. Familiarize-se com a estrutura do projeto
2. Execute os testes existentes
3. Desenvolva suas funcionalidades
4. Teste extensivamente
5. Documente suas mudanças
