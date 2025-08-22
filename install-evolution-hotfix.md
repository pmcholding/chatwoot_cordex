# Hotfix Evolution API - Guia de Instalação

## Visão Geral

Este hotfix permite instalar a integração Evolution API em outras instâncias do Chatwoot rodando em containers Docker, baixando os arquivos diretamente do GitHub via URLs raw, sem necessidade de rebuild da imagem.

## Arquivos Modificados

A implementação Evolution API inclui os seguintes arquivos:

### Backend (Ruby/Rails)
- `app/controllers/api/v1/accounts/inboxes/evolution_whatsapp_controller.rb`
- `app/controllers/api/v1/webhooks/evolution_controller.rb`
- `app/services/evolution_api_service.rb`
- `app/models/channel/api.rb` (métodos Evolution adicionados)

### Frontend (Vue.js)
- `app/javascript/dashboard/api/evolutionWhatsapp.js`
- `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/EvolutionWhatsapp.vue`
- `app/javascript/dashboard/routes/dashboard/settings/inbox/components/WhatsAppQRCode.vue`

### Traduções
- `app/javascript/dashboard/i18n/locale/en/inboxMgmt.json`
- `app/javascript/dashboard/i18n/locale/pt_BR/inboxMgmt.json`

### Configuração
- `config/routes.rb` (rotas Evolution API)

### Testes (opcionais)
- `spec/services/evolution_api_service_spec.rb`
- `spec/models/channel/api_spec.rb`

## Como Usar o Hotfix

### 1. Download do Script

```bash
# Baixar script diretamente do GitHub
curl -L -o hotfix-evolution.sh https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/hotfix-evolution.sh

# Torne o script executável
chmod +x hotfix-evolution.sh
```

### 2. Configuração de Variáveis

```bash
# Definir o nome do container Chatwoot (padrão: chatwoot)
export CHATWOOT_CONTAINER=meu-chatwoot-container

# Opcional: definir URL base do GitHub (padrão já configurado)
export GITHUB_RAW_URL=https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821
```

### 3. Execução

```bash
# Execute o script de hotfix
./hotfix-evolution.sh
```

O script irá:
1. Baixar todos os arquivos Evolution do GitHub
2. Fazer backup dos arquivos existentes
3. Instalar os novos arquivos no container
4. Configurar rotas e dependências
5. Recompilar assets e reiniciar a aplicação

### 4. Configuração de Ambiente

Após a instalação, configure as seguintes variáveis de ambiente no container:

```bash
# No container ou docker-compose.yml
EVOLUTION_API_URL_V2=https://evolution-api.exemplo.com
EVOLUTION_API_KEY=sua-chave-api
FRONTEND_URL=https://chatwoot.exemplo.com
```

## O que o Script Faz

1. **Backup**: Cria backup dos arquivos existentes
2. **Cópia**: Copia todos os arquivos Evolution para o container
3. **Rotas**: Adiciona rotas da Evolution API ao `routes.rb`
4. **Dependências**: Instala HTTParty se necessário
5. **Assets**: Recompila os assets do frontend
6. **Reinicialização**: Reinicia a aplicação

## Uso da Funcionalidade

### 1. Acessar Configurações
1. Faça login no Chatwoot
2. Vá para Configurações > Caixas de Entrada
3. Clique em "Adicionar Caixa de Entrada"

### 2. Configurar Evolution WhatsApp
1. Selecione "Evolution WhatsApp" como canal
2. Configure o nome da caixa de entrada
3. O sistema criará automaticamente uma instância Evolution

### 3. Conectar WhatsApp
1. Use QR Code para conectar
2. Ou conecte via número de telefone
3. Configure as opções da instância

## Estrutura da API Evolution

### Endpoints Disponíveis

```
POST   /api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/initialize_instance
GET    /api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/connection_status
GET    /api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/connect_qr_code
DELETE /api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/disconnect
POST   /api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/connect_with_number
POST   /api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/update_settings
GET    /api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/webhook_info
GET    /api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/instance_settings
POST   /webhooks/evolution/{instance_name}
```

## Troubleshooting

### Problemas Comuns

1. **Container não encontrado**
   ```bash
   # Verificar containers rodando
   docker ps
   
   # Definir container correto
   export CHATWOOT_CONTAINER=nome-correto
   ```

2. **Permissões**
   ```bash
   # Executar como usuário com acesso ao Docker
   sudo ./hotfix-evolution.sh
   ```

3. **Assets não carregando**
   ```bash
   # Recompilar assets manualmente
   docker exec chatwoot-container bundle exec rails assets:precompile RAILS_ENV=production
   ```

4. **Erro de dependências**
   ```bash
   # Instalar dependências manualmente
   docker exec chatwoot-container bundle install
   ```

### Reverter Instalação

Se necessário reverter:

```bash
# Usar backup criado pelo script
BACKUP_DIR="/tmp/chatwoot-evolution-backup-YYYYMMDD_HHMMSS"

# Restaurar arquivos
docker cp $BACKUP_DIR/evolution_whatsapp_controller.rb.backup chatwoot:/app/controllers/api/v1/accounts/inboxes/evolution_whatsapp_controller.rb

# Reiniciar container
docker restart chatwoot
```

## Requisitos

- Docker instalado e rodando
- Container Chatwoot ativo
- Acesso de escrita ao container
- Evolution API server configurado
- Variáveis de ambiente configuradas

## Notas Importantes

- O script cria backup automaticamente antes de qualquer modificação
- Assets são recompilados automaticamente
- A aplicação é reiniciada após a instalação
- Logs da aplicação podem ser verificados para problemas
- A funcionalidade requer configuração correta da Evolution API

## Suporte

Para problemas específicos:
1. Verificar logs do container: `docker logs chatwoot-container`
2. Verificar se a Evolution API está acessível
3. Confirmar configuração das variáveis de ambiente
4. Testar endpoints via curl ou Postman