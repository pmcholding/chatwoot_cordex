# Lista de URLs Raw dos Arquivos Evolution API

## URLs Base
- **Repository**: https://github.com/pmcholding/chatwoot_cordex
- **Branch**: scheduled-messages-backup-20250821
- **Raw Base URL**: https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821

## Arquivos Backend (Ruby/Rails)

### Controllers
```
https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/app/controllers/api/v1/accounts/inboxes/evolution_whatsapp_controller.rb

https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/app/controllers/api/v1/webhooks/evolution_controller.rb
```

### Services
```
https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/app/services/evolution_api_service.rb
```

### Models
```
https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/app/models/channel/api.rb
```

## Arquivos Frontend (Vue.js/JavaScript)

### API Client
```
https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/app/javascript/dashboard/api/evolutionWhatsapp.js
```

### Components
```
https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/app/javascript/dashboard/routes/dashboard/settings/inbox/channels/EvolutionWhatsapp.vue

https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/app/javascript/dashboard/routes/dashboard/settings/inbox/components/WhatsAppQRCode.vue
```

## Traduções (i18n)

### Inglês
```
https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/app/javascript/dashboard/i18n/locale/en/inboxMgmt.json
```

### Português Brasil
```
https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/app/javascript/dashboard/i18n/locale/pt_BR/inboxMgmt.json
```

## Configuração

### Routes
```
https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/config/routes.rb
```

## Arquivos de Teste (Opcionais)

### Services Specs
```
https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/spec/services/evolution_api_service_spec.rb
```

### Models Specs
```
https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/spec/models/channel/api_spec.rb
```

## Script de Instalação

### Hotfix Script
```
https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/hotfix-evolution.sh
```

### Documentação
```
https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/install-evolution-hotfix.md
```

## Como Usar

### Download e Execução Direta
```bash
# Baixar e executar o script de hotfix
curl -L https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/hotfix-evolution.sh | bash
```

### Download e Execução Manual
```bash
# Baixar o script
curl -L -o hotfix-evolution.sh https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/hotfix-evolution.sh

# Dar permissão de execução
chmod +x hotfix-evolution.sh

# Executar
./hotfix-evolution.sh
```

### Configurar Container Personalizado
```bash
# Definir nome do container antes de executar
export CHATWOOT_CONTAINER=meu-container-chatwoot

# Executar o script
./hotfix-evolution.sh
```

## Verificação Manual de Arquivos

Para verificar se os arquivos estão disponíveis:

```bash
# Testar download de um arquivo específico
curl -I https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/app/services/evolution_api_service.rb

# Baixar um arquivo para teste
curl -L -o test-file.rb https://raw.githubusercontent.com/pmcholding/chatwoot_cordex/refs/heads/scheduled-messages-backup-20250821/app/services/evolution_api_service.rb
```