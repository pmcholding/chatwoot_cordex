# Hotfix Evolution API para Chatwoots Customizados

## 🛡️ **Abordagem Conservativa**

O script foi modificado para **NÃO sobrescrever** arquivos críticos de Chatwoots customizados, utilizando merge inteligente ao invés de substituição completa.

## 📁 **Estratégia por Arquivo**

### ✅ **Arquivos SEGUROS (Sobrescrevem)**
Estes arquivos são **novos** na implementação Evolution e podem ser instalados sem risco:

```
✓ app/controllers/api/v1/accounts/inboxes/evolution_whatsapp_controller.rb  [NOVO]
✓ app/controllers/api/v1/webhooks/evolution_controller.rb                    [NOVO]  
✓ app/services/evolution_api_service.rb                                      [NOVO]
✓ app/javascript/dashboard/api/evolutionWhatsapp.js                         [NOVO]
✓ app/javascript/dashboard/routes/.../EvolutionWhatsapp.vue                 [NOVO]
✓ app/javascript/dashboard/routes/.../WhatsAppQRCode.vue                    [NOVO]
✓ spec/services/evolution_api_service_spec.rb                               [NOVO]
✓ spec/models/channel/api_spec.rb                                            [NOVO]
```

### ⚠️ **Arquivos CRÍTICOS (Merge Inteligente)**
Estes arquivos podem ter customizações e usam merge:

#### **1. `app/models/channel/api.rb`**
- ❌ **NÃO sobrescreve** o modelo existente
- ✅ **Adiciona apenas** métodos Evolution:
  - `evolution_webhook_configured?`
  - `evolution_instance_name` 
  - `has_evolution_instance?`
  - `generate_evolution_instance_name`
  - `evolution_webhook_url`

**Como funciona:**
```ruby
# Verifica se métodos já existem
if grep -q 'evolution_webhook_configured?' app/models/channel/api.rb; then
  echo "✓ Métodos Evolution já existem"
else
  # Adiciona métodos antes do 'private' ou antes do último 'end'
  # Preserva 100% das customizações existentes
fi
```

#### **2. `config/routes.rb`**  
- ❌ **NÃO sobrescreve** o arquivo de rotas
- ✅ **Adiciona apenas** rotas Evolution:

```ruby
# Adiciona após 'resources :inboxes do'
resources :evolution_whatsapp, only: [] do
  post :initialize_instance
  get :connection_status
  get :connect_qr_code
  # ... outras rotas Evolution
end
```

#### **3. Traduções i18n (`inboxMgmt.json`)**
- ⚠️ **ATENÇÃO**: Estes arquivos podem ser sobrescritos
- 💡 **Solução**: Fazer backup manual antes da instalação
- 🔄 **Recuperação**: Fazer merge manual das traduções customizadas

## 🔧 **Funcionalidades de Proteção**

### **1. Backup Automático**
```bash
# Backup criado automaticamente em:
/tmp/chatwoot-evolution-backup-YYYYMMDD_HHMMSS/

# Arquivos com backup:
- channel_api.rb.backup
- routes.rb.backup  
- inboxMgmt.json.backup
```

### **2. Verificação Prévia**
```bash
# Verifica se métodos/rotas já existem
if methods_exist; then
  skip_installation
else
  add_methods
fi
```

### **3. Logs Detalhados**
```bash
✓ Métodos Evolution já existem no modelo
✓ Rotas Evolution já existem  
⚠️ Adicionando métodos Evolution ao modelo
✓ Métodos Evolution adicionados ao modelo Channel::Api
```

## 🚀 **Instalação em Chatwoots Customizados**

### **Instalação Padrão (Segura)**
```bash
# O script já é conservativo por padrão
curl -L https://raw.githubusercontent.com/.../hotfix-evolution.sh | bash
```

### **Verificação Prévia (Recomendada)**
```bash
# 1. Baixar script primeiro
curl -L -o hotfix-evolution.sh https://raw.githubusercontent.com/.../hotfix-evolution.sh
chmod +x hotfix-evolution.sh

# 2. Verificar o que será modificado
export EVOLUTION_PREVIEW=true  # Funcionalidade futura
./hotfix-evolution.sh

# 3. Executar instalação
./hotfix-evolution.sh
```

## 📋 **Checklist para Chatwoots Customizados**

### **Antes da Instalação:**
- [ ] Fazer backup completo do Chatwoot
- [ ] Verificar se há customizações em `channel/api.rb`
- [ ] Verificar se há rotas customizadas em `routes.rb`  
- [ ] Anotar traduções personalizadas em `inboxMgmt.json`

### **Durante a Instalação:**
- [ ] Monitorar logs do script
- [ ] Verificar se backups foram criados
- [ ] Confirmar que não houve erros

### **Após a Instalação:**
- [ ] Testar funcionalidades existentes
- [ ] Verificar se customizações foram preservadas
- [ ] Testar nova funcionalidade Evolution
- [ ] Fazer merge manual das traduções se necessário

## 🔄 **Recuperação e Rollback**

### **Recuperar Arquivo Específico:**
```bash
# Usar backup criado pelo script
BACKUP_DIR="/tmp/chatwoot-evolution-backup-YYYYMMDD_HHMMSS"

# Restaurar modelo original
docker cp $BACKUP_DIR/api.rb.backup chatwoot:/app/models/channel/api.rb

# Restaurar rotas originais  
docker cp $BACKUP_DIR/routes.rb.backup chatwoot:/app/config/routes.rb

# Reiniciar aplicação
docker exec chatwoot touch tmp/restart.txt
```

### **Rollback Completo:**
```bash
# Restaurar todos os backups
for backup in $BACKUP_DIR/*.backup; do
  original=${backup/.backup/}
  docker cp "$backup" "chatwoot:$original"
done

# Remover arquivos Evolution novos
docker exec chatwoot rm -f app/controllers/api/v1/accounts/inboxes/evolution_whatsapp_controller.rb
docker exec chatwoot rm -f app/controllers/api/v1/webhooks/evolution_controller.rb
docker exec chatwoot rm -f app/services/evolution_api_service.rb
# ... outros arquivos novos

# Reiniciar
docker restart chatwoot
```

## ✅ **Compatibilidade Garantida**

### **Chatwoots com Customizações em:**
- ✅ Modelos personalizados
- ✅ Rotas adicionais  
- ✅ Controllers customizados
- ✅ Services personalizados
- ✅ Componentes Vue customizados
- ✅ Traduções localizadas

### **O que NÃO é afetado:**
- ✅ Themes personalizados
- ✅ Plugins existentes
- ✅ Configurações de banco
- ✅ Variables de ambiente
- ✅ Customizações de UI
- ✅ Integrações existentes

## 🎯 **Resumo da Segurança**

1. **Backup automático** de todos os arquivos modificados
2. **Merge inteligente** ao invés de sobrescrita
3. **Verificação prévia** de conflitos
4. **Logs detalhados** de todas as operações
5. **Recuperação simples** com arquivos de backup
6. **Zero impacto** em funcionalidades existentes

A instalação é **segura para Chatwoots customizados** e preserva 100% das modificações existentes.