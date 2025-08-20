# 📋 Mini PRD: Canal WhatsApp com Conexão QR Code

## 🎯 Objetivo
Criar uma nova opção de canal "WhatsApp" que utiliza o **Channel API existente** com um **adendo especial**: conexão via QR Code usando Evolution API na etapa final, diferenciando do canal atual que será renomeado para "WABA" (WhatsApp Business API).

## 🔍 Contexto Atual
- Existe um canal "WhatsApp" que usa WhatsApp Business API
- Desenvolvemos funcionalidades de conexão via QR Code usando Evolution API
- Necessidade de oferecer ambas as opções aos usuários

## 📝 Requisitos Funcionais

### 1. Renomeação do Canal Existente
- **Atual**: "WhatsApp" → **Novo**: "WABA" (WhatsApp Business API)
- Manter toda funcionalidade existente
- Atualizar textos e traduções

### 2. Novo Canal WhatsApp
- **Nome**: "WhatsApp" 
- **Descrição**: "Conecte via QR Code usando Evolution API"
- **Ícone**: Mesmo ícone do WhatsApp atual
- **Posicionamento**: Após o canal WABA na lista

### 3. Fluxo de Criação (4 Passos)

**IMPORTANTE**: Este canal utiliza o **Channel API padrão** do Chatwoot com um **adendo especial** na etapa 4.

#### Passo 1: Seleção do Canal
- Mostrar "WhatsApp" como opção
- Descrição clara da diferença vs WABA

#### Passo 2: Configuração Básica
- Nome da caixa de entrada

#### Passo 3: Adicionar Agentes
- Fluxo padrão de adição de agentes

#### Passo 4: **"Está tudo pronto para começar!"** + Conexão QR Code
- **Texto padrão**: "Está tudo pronto para começar!"
- **ADENDO ESPECIAL**: Interface de conexão QR Code
- Timer de 20 segundos
- Status de conexão
- Configurações da instância
- Botões de ação após conexão:
  - 🔧 **"Mais configurações"** - Leva para aba de configurações da inbox
  - 🚀 **"Leva-me lá"** - Vai direto para a caixa de entrada

## 🛠️ Implementação Técnica

### Arquivos a Modificar

1. **Canal Factory/Router**
   - `app/javascript/dashboard/routes/dashboard/settings/inbox/ChannelFactory.vue`
   - Adicionar novo canal "WhatsApp Evolution"

2. **Componentes de Criação**
   - Criar `EvolutionWhatsapp.vue` (novo)
   - Modificar lista de canais disponíveis

3. **Backend**
   - **Reutilizar Channel API existente** (`Channel::Api`)
   - Adicionar campos específicos para Evolution API
   - Controller para funcionalidades QR Code (já existe)
   - Validações para credenciais Evolution API

4. **Traduções**
   - Adicionar textos em EN/ES/PT-BR
   - Diferenciar WABA vs WhatsApp Evolution

### Estrutura de Dados

```ruby
# Reutiliza Channel::Api existente com campos adicionais
class Channel::Api < ApplicationRecord
  belongs_to :account

  # Campos existentes
  validates :webhook_url, presence: true

  # Novos campos para Evolution API (quando provider = 'evolution_whatsapp')
  validates :evolution_api_url, presence: true, if: :evolution_whatsapp?
  validates :evolution_api_key, presence: true, if: :evolution_whatsapp?
  validates :evolution_instance_name, presence: true, if: :evolution_whatsapp?

  def evolution_whatsapp?
    provider == 'evolution_whatsapp'
  end
end
```

### Fluxo de Criação

```javascript
// Passo 1: Seleção
channels: [
  { name: 'WABA', type: 'whatsapp_business' },
  { name: 'WhatsApp', type: 'evolution_whatsapp' }, // NOVO
  // ... outros canais
]

// Passo 4: Conexão QR
<WhatsAppQRCode 
  :inbox="inbox" 
  :is-creation-flow="true"
  @connected="onWhatsAppConnected"
/>
```

## 🎨 Interface do Usuário

### Lista de Canais
```
📱 WABA
   Conecte via WhatsApp Business API oficial

📱 WhatsApp  
   Conecte via QR Code usando Evolution API

📧 Email
   ...
```

### Passo 4: Conexão QR
- Reutilizar componente `WhatsAppQRCode.vue` existente
- Adaptar para fluxo de criação
- Mostrar progresso da conexão
- **Após conexão bem-sucedida**:
  ```
  ✅ WhatsApp Conectado com Sucesso!
  
  [Configurações da Instância]
  - Rejeitar Chamadas: ❌
  - Ignorar Grupos: ❌  
  - Sempre Online: ❌
  - Ler Mensagens: ❌
  - Status de Leitura: ❌
  - Sincronizar Histórico: ❌
  
  [🔧 Mais configurações]  [🚀 Leva-me lá]
  ```

## 🔄 Fluxo Completo

1. **Usuário** acessa `/settings/inboxes/new`
2. **Seleciona** "WhatsApp" (novo canal usando Channel API)
3. **Configura** nome da inbox (fluxo padrão Channel API)
4. **Adiciona** agentes (fluxo padrão Channel API)
5. **Etapa "Está tudo pronto!"** + **ADENDO QR Code**:
   - Mostra tela padrão "Está tudo pronto para começar!"
   - **PLUS**: Interface de conexão QR Code
6. **Conecta** via QR Code usando Evolution API
7. **Vê configurações** da instância conectada
8. **Escolhe ação**:
   - "Mais configurações" → `/settings/inboxes/{id}`
   - "Leva-me lá" → `/conversations`

## 📊 Critérios de Sucesso

- [ ] Canal WABA renomeado sem quebrar funcionalidade
- [ ] Novo canal WhatsApp aparece na lista
- [ ] Fluxo de 4 passos funciona completamente
- [ ] QR Code conecta e cria inbox automaticamente
- [ ] Botões "Mais configurações" e "Leva-me lá" funcionam
- [ ] Traduções em 3 idiomas (EN/ES/PT-BR)
- [ ] Interface intuitiva e clara

## 🚀 Entregáveis

1. **Renomeação WABA** - Atualizar textos existentes
2. **Novo Canal** - Adicionar à lista de canais
3. **Componente Criação** - Fluxo de 4 passos
4. **Integração QR** - Reutilizar componente existente
5. **Botões de Ação** - "Mais configurações" e "Leva-me lá"
6. **Traduções** - Textos em 3 idiomas
7. **Testes** - Validar fluxo completo

## 🧪 Validação e Testes

### Playwright MCP Testing
**URL de Teste**: `http://localhost:3000/app/accounts/1/settings/inboxes/new`

#### Cenários de Teste:
1. **Verificar Lista de Canais**
   - [ ] Canal "WABA" aparece (renomeado)
   - [ ] Canal "WhatsApp" aparece (novo)
   - [ ] Descrições corretas para cada canal

2. **Fluxo de Criação WhatsApp**
   - [ ] Passo 1: Seleção do canal funciona
   - [ ] Passo 2: Configuração básica aceita dados
   - [ ] Passo 3: Adição de agentes funciona
   - [ ] Passo 4: Interface QR Code aparece corretamente

3. **Funcionalidade QR Code**
   - [ ] Botão "Conectar com QR Code" funciona
   - [ ] Timer de 20 segundos aparece
   - [ ] Status de conexão atualiza
   - [ ] Configurações da instância carregam

4. **Botões de Ação Final**
   - [ ] Botão "Mais configurações" redireciona corretamente
   - [ ] Botão "Leva-me lá" vai para conversas
   - [ ] Inbox é criada com sucesso

#### Comandos Playwright MCP:
```javascript
// Navegar para criação de inbox
await page.goto('http://localhost:3000/app/accounts/1/settings/inboxes/new');

// Selecionar canal WhatsApp
await page.click('[data-testid="whatsapp-evolution-channel"]');

// Testar fluxo completo
await page.fill('[data-testid="inbox-name"]', 'Teste WhatsApp Evolution');
await page.click('[data-testid="next-step"]');
// ... continuar teste
```

## 📋 Próximos Passos

1. **Validar PRD** com stakeholders
2. **Testar com Playwright MCP** em `http://localhost:3000/app/accounts/1/settings/inboxes/new`
3. Estimar esforço de desenvolvimento
4. Definir prioridade vs outras features
5. Iniciar implementação por etapas
6. Testes em ambiente de desenvolvimento

---

**Este PRD serve como guia para implementação em uma nova conversa, garantindo que todos os aspectos sejam cobertos de forma organizada e sistemática.**
