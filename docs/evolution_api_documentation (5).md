# PRD: Evolution API Integration - WhatsApp QR Code Feature

## 1. Visão Geral

### 1.1 Objetivo
Integrar a Evolution API ao Chatwoot para permitir conexão de instâncias WhatsApp através de QR Code ou código de pareamento, proporcionando gerenciamento completo de configurações WhatsApp dentro da interface do Chatwoot.

### 1.2 Escopo
- Criar nova aba "WhatsApp QR Code" nas configurações de caixas do tipo API Channel
- Gerenciar instâncias WhatsApp automaticamente (criar/recuperar)
- Implementar conexão via QR Code e número de telefone
- Permitir configuração de comportamentos WhatsApp
- Armazenar URLs de webhook no banco de dados do Chatwoot

## 2. Configurações de Ambiente

### 2.1 Variáveis Requeridas
```bash
EVOLUTION_API_URL_V2=https://evo.cordex.ai
EVOLUTION_API_KEY=0a128ed725af4c594b33bda5cbb7b4ae
FRONTEND_URL=https://app.cordex.ai
```

### 2.2 Observações
- `chatwootAccountId` deve ser obtido dinamicamente do contexto da requisição
- `FRONTEND_URL` é usado como `chatwootUrl` na Evolution API
- `CHATWOOT_TOKEN` agora é obtido dinamicamente do access token do usuário atual
- Cada usuário possui seu próprio access token único para autenticação com a Evolution API

## 3. Fluxo Funcional

### 3.1 Abertura da Aba "WhatsApp QR Code"

**Sequência de Operações:**

1. **Verificação de Instância Existente**
   - Consultar campo `webhook_url` no modelo `Channel::Api`
   - Se `webhook_url` existe: extrair `instance_name` e prosseguir para verificação de estado
   - Se `webhook_url` não existe: criar nova instância

2. **Criação de Nova Instância (se necessário)**
   - Gerar `instance_name` = `{account_id}_{inbox_id}_{inbox_identifier}`
   - Chamar Evolution API para criar instância
   - Salvar `webhook_url` no banco: `https://evo.cordex.ai/chatwoot/webhook/{instance_name}`

3. **Verificação de Estado da Conexão**
   - Consultar estado atual da instância na Evolution API
   - Determinar interface a ser exibida baseada no estado

### 3.2 Estados da Interface

#### Estado: Não Conectado (`state` ≠ "open")
**Elementos da UI:**
- Badge vermelho "WhatsApp não conectado"
- Informação da instância (nova criada ou existente encontrada)
- Botão "Conectar com QR Code"
- Botão "Conectar com Número"
- Área para exibir QR Code ou código de pareamento

#### Estado: Conectado (`state` = "open")
**Elementos da UI:**
- Badge verde "WhatsApp conectado"
- Informação da instância
- Formulário de configurações WhatsApp
- Botão "Salvar Configurações"

### 3.3 Conexão WhatsApp

#### Via QR Code
- Gerar QR Code através da Evolution API
- Exibir QR Code na interface
- Instruções para escaneamento no WhatsApp

#### Via Número de Telefone
- Modal para inserir número com código do país
- Gerar código de pareamento
- Exibir código para inserção manual no WhatsApp

### 3.4 Configurações WhatsApp

**Parâmetros Configuráveis:**
- `rejectCall`: Rejeitar chamadas automaticamente
- `msgCall`: Mensagem ao rejeitar chamada
- `groupsIgnore`: Ignorar mensagens de grupos
- `alwaysOnline`: Sempre mostrar como online
- `readMessages`: Confirmar leitura de mensagens
- `readStatus`: Ver status das mensagens
- `syncFullHistory`: Sincronizar histórico completo

## 4. Especificações da Evolution API

### 4.1 Endpoint: Criar Instância
**Método:** `POST /instance/create`

**Payload Padrão:**
```json
{
  "instanceName": "{account_id}_{inbox_id}_{inbox_identifier}",
  "integration": "WHATSAPP-BAILEYS",
  "chatwootAccountId": "{account_id}",
  "chatwootToken": "{CHATWOOT_TOKEN}",
  "chatwootUrl": "{FRONTEND_URL}",
  "chatwootSignMsg": false,
  "chatwootReopenConversation": false,
  "chatwootConversationPending": false,
  "chatwootImportContacts": false,
  "chatwootNameInbox": "{nome_da_caixa}",
  "chatwootMergeBrazilContacts": false,
  "chatwootImportMessages": false,
  "chatwootDaysLimitImportMessages": 7
}
```

### 4.2 Endpoint: Verificar Estado da Conexão
**Método:** `GET /instance/connectionState/{instance}`

**Resposta Esperada:**
```json
{
  "instance": {
    "instanceName": "instance-name",
    "state": "open" // ou outros estados
  }
}
```

### 4.3 Endpoint: Conectar Instância
**Método:** `GET /instance/connect/{instance}`

**Parâmetros Opcionais:**
- `number`: Número de telefone para conexão específica

**Resposta Esperada:**
```json
{
  "pairingCode": "ABC123",
  "code": "qr-code-string",
  "count": 1
}
```

### 4.4 Endpoint: Buscar Configurações
**Método:** `GET /settings/find/{instance}`

**Resposta Esperada:**
```json
{
  "reject_call": false,
  "groups_ignore": false,
  "always_online": false,
  "read_messages": false,
  "read_status": false,
  "sync_full_history": false
}
```

### 4.5 Endpoint: Atualizar Configurações
**Método:** `POST /settings/set/{instance}`

**Payload:**
```json
{
  "rejectCall": false,
  "msgCall": "Mensagem personalizada",
  "groupsIgnore": false,
  "alwaysOnline": false,
  "readMessages": false,
  "readStatus": false,
  "syncFullHistory": false
}
```

## 5. Requisitos de Banco de Dados

### 5.1 Modelo Channel::Api

**Novo Campo Requerido:**
- `webhook_url`: String, URL do webhook para a Evolution API

**Métodos Necessários:**
- `evolution_webhook_configured?`: Verifica se webhook está configurado
- `evolution_instance_name`: Extrai nome da instância da URL
- `has_evolution_instance?`: Verifica se instância Evolution existe

### 5.2 Validações
- `webhook_url` deve aceitar URLs HTTP/HTTPS válidas
- Campo opcional (pode ser nulo)

## 6. Requisitos de Interface

### 6.1 Nova Aba nas Configurações
- Adicionar aba "WhatsApp QR Code" apenas para caixas do tipo `Channel::Api`
- Aba deve aparecer após "Collaborators"

### 6.2 Componente Principal

**Funcionalidades Requeridas:**
- Auto-inicialização ao abrir a aba
- Polling automático de status (5 segundos)
- Feedback visual de loading states
- Mensagens de sucesso/erro
- Formulário reativo de configurações

**Estados de Loading:**
- Carregando inicialização
- Conectando com QR Code
- Conectando com número
- Atualizando configurações

### 6.3 Modal de Conexão por Número
- Campo de entrada para número de telefone
- Validação de formato
- Botões de ação (Cancelar/Conectar)

## 7. Regras de Negócio

### 7.1 Geração do Nome da Instância
**Formato:** `{account_id}_{inbox_id}_{inbox_identifier}`
- Deve ser único por caixa
- Usado como identificador na Evolution API

### 7.2 Webhook URL
**Formato:** `https://evo.cordex.ai/chatwoot/webhook/{instance_name}`
- Salvo no banco após criação bem-sucedida da instância
- Usado pela Evolution API para enviar eventos

### 7.3 Nome da Caixa
- Campo `chatwootNameInbox` deve usar o nome atual da caixa (`inbox.name`)
- Atualizado dinamicamente conforme nome da caixa

### 7.4 Reutilização de Instâncias
- Verificar sempre primeiro se instância já existe (via `webhook_url`)
- Não criar instâncias duplicadas
- Recuperar estado de instâncias existentes

## 8. API Endpoints do Chatwoot

### 8.1 Endpoints Requeridos

**POST** `/api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/initialize_instance`
- Inicializa ou recupera instância existente
- Retorna dados da instância e estado da conexão

**GET** `/api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/connection_status`
- Verifica estado atual da conexão
- Retorna configurações se conectado

**POST** `/api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/connect_qr_code`
- Gera QR Code para conexão
- Retorna base64 do QR Code

**POST** `/api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/connect_with_number`
- Conecta usando número de telefone
- Requer parâmetro `phone_number`

**PATCH** `/api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/update_settings`
- Atualiza configurações da instância
- Requer objeto `settings`

**GET** `/api/v1/accounts/{account_id}/inboxes/{inbox_id}/evolution_whatsapp/webhook_info`
- Retorna informações do webhook configurado
- Status da configuração

## 9. Tratamento de Webhooks

### 9.1 Endpoint de Recebimento
**POST** `/api/v1/webhooks/evolution/{instance_name}`
- Recebe eventos da Evolution API
- Processa mensagens e atualizações de estado

### 9.2 Eventos Suportados
- `messages.upsert`: Novas mensagens recebidas
- `connection.update`: Mudanças no estado da conexão

## 10. Casos de Uso

### 10.1 Primeira Configuração
1. Usuário abre aba "WhatsApp QR Code"
2. Sistema cria nova instância automaticamente
3. Sistema salva webhook_url no banco
4. Sistema exibe botões de conexão
5. Usuário conecta via QR Code ou número
6. Sistema monitora estado e atualiza interface

### 10.2 Configuração Existente
1. Usuário abre aba "WhatsApp QR Code"
2. Sistema encontra webhook_url existente
3. Sistema extrai instance_name e verifica estado
4. Se conectado: exibe configurações
5. Se não conectado: exibe botões de conexão

### 10.3 Reconexão
1. Instância perde conexão
2. Sistema detecta mudança de estado via polling
3. Interface atualiza para mostrar estado desconectado
4. Usuário pode reconectar usando botões disponíveis

## 11. Critérios de Aceitação

### 11.1 Funcional
- [ ] Aba "WhatsApp QR Code" aparece apenas em API Channels
- [ ] Sistema verifica instância existente antes de criar nova
- [ ] QR Code é gerado e exibido corretamente
- [ ] Conexão por número funciona com código de pareamento
- [ ] Configurações são carregadas e salvadas corretamente
- [ ] Polling de status funciona automaticamente

### 11.2 Técnico
- [ ] Webhook URL é salvo no banco após criação da instância
- [ ] Instâncias não são duplicadas
- [ ] Estados de loading são exibidos apropriadamente
- [ ] Tratamento de erros está implementado
- [ ] Logs apropriados são gerados

### 11.3 UX
- [ ] Interface responde em tempo real
- [ ] Feedback visual claro para cada ação
- [ ] Mensagens de erro são informativas
- [ ] Estados de conexão são facilmente identificáveis

## 12. Considerações Técnicas

### 12.1 Performance
- Implementar debounce em atualizações frequentes
- Cache de estados quando apropriado
- Otimizar polling para reduzir carga

### 12.2 Segurança
- Validar todas as entradas de usuário
- Sanitizar dados antes de enviar para Evolution API
- Proteger endpoints com autenticação adequada

### 12.3 Monitoramento
- Logs detalhados de todas as operações
- Métricas de uso da feature
- Alertas para falhas de conexão

---

**Este PRD define todos os requisitos necessários para implementar a integração Evolution API no Chatwoot.**