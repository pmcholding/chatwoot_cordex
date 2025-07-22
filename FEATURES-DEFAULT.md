# Funcionalidades Habilitadas por Padrão

Este documento descreve as funcionalidades que são habilitadas automaticamente para novas contas no Cordex.

## 🎯 **Funcionalidades Habilitadas por Padrão**

### **1. WhatsApp Campaign**
- **Nome técnico:** `whatsapp_campaign`
- **Descrição:** Permite criar e gerenciar campanhas de WhatsApp
- **Status:** ✅ Habilitada por padrão
- **Tipo:** Premium

### **2. WhatsApp Embedded Signup**
- **Nome técnico:** `whatsapp_embedded_signup`
- **Descrição:** Permite configurar WhatsApp Business usando o fluxo de signup integrado
- **Status:** ✅ Habilitada por padrão
- **Tipo:** Standard

### **3. Captain Integration**
- **Nome técnico:** `captain_integration`
- **Descrição:** Integração com o sistema de IA Captain para respostas automáticas
- **Status:** ✅ Habilitada por padrão
- **Tipo:** Premium

## 🔧 **Como Funciona**

### **Para Novas Contas**
Quando uma nova conta é criada, essas funcionalidades são automaticamente habilitadas através de:

1. **Configuração padrão** em `config/features.yml`
2. **Initializer** em `config/initializers/default_features.rb`
3. **Configuração de instalação** `ACCOUNT_LEVEL_FEATURE_DEFAULTS`

### **Para Contas Existentes**
As contas existentes podem ter essas funcionalidades habilitadas através do script:

```bash
docker exec -i CONTAINER_ID bundle exec rails runner /tmp/enable_features.rb
```

## 📋 **Configuração Técnica**

### **Arquivo de Features (`config/features.yml`)**
```yaml
- name: whatsapp_campaign
  display_name: WhatsApp Campaign
  enabled: true

- name: whatsapp_embedded_signup
  display_name: WhatsApp Embedded Signup
  enabled: true

- name: captain_integration
  display_name: Captain
  enabled: true
  premium: true
```

### **Initializer (`config/initializers/default_features.rb`)**
- Executa após a inicialização do Rails
- Cria/atualiza a configuração `ACCOUNT_LEVEL_FEATURE_DEFAULTS`
- Garante que as features padrão estejam habilitadas
- Limpa o cache de configuração

## 🚀 **Benefícios**

1. **Experiência do usuário melhorada:** Novas contas já vêm com funcionalidades essenciais
2. **Redução de suporte:** Menos tickets sobre "como habilitar funcionalidades"
3. **Maior adoção:** Usuários descobrem e usam mais funcionalidades
4. **Consistência:** Todas as contas têm o mesmo conjunto base de funcionalidades

## 🔍 **Verificação**

Para verificar se as funcionalidades estão habilitadas:

```ruby
# No Rails console
account = Account.first
account.feature_enabled?('whatsapp_campaign')
account.feature_enabled?('whatsapp_embedded_signup')
account.feature_enabled?('captain_integration')
```

## 📝 **Logs**

O sistema registra logs quando configura as funcionalidades padrão:

```
[DEFAULT_FEATURES] Creating ACCOUNT_LEVEL_FEATURE_DEFAULTS configuration
[DEFAULT_FEATURES] Enabling feature by default: whatsapp_campaign
[DEFAULT_FEATURES] Enabling feature by default: whatsapp_embedded_signup
[DEFAULT_FEATURES] Enabling feature by default: captain_integration
[DEFAULT_FEATURES] Configuration created with X features
```

## ⚠️ **Considerações**

1. **Performance:** O initializer só executa em produção
2. **Segurança:** Funcionalidades premium são habilitadas mas podem ter limitações de billing
3. **Compatibilidade:** Funciona com contas novas e existentes
4. **Manutenção:** Mudanças no `features.yml` são aplicadas automaticamente
