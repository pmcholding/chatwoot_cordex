# AI Agent - Planejamento de Implementação

## Visão Geral

Criar um sistema AI Agent para substituir o Captain (que será descontinuado por ser enterprise):
- Quando cria um assistente, ele cria um Agent Bot
- Quando atribui a uma caixa (inbox), cada nova conversa é auto-assigned a ele
- Responde automaticamente quando está assigned
- Sistema independente e simplificado
- Tem atalho próprio na SideBar

## Análise do Captain (Referência para Substituição)

### Estrutura Atual do Captain

**Tabelas:**
- `captain_assistants` - Assistentes de IA
- `captain_assistant_responses` - Respostas/embeddings
- `captain_inboxes` - Relacionamento assistant <-> inbox

**Componentes Principais:**
- `Captain::Assistant` - Model principal
- `CaptainInbox` - Model de relacionamento
- `CaptainListener` - Escuta eventos de conversa
- `Captain::Conversation::ResponseBuilderJob` - Gera respostas
- `Enterprise::MessageTemplates::HookExecutionService` - Detecta mensagens incoming

**Fluxo de Funcionamento:**
1. Mensagem incoming chega
2. `HookExecutionService` detecta e verifica se Captain está ativo
3. Agenda `ResponseBuilderJob` para gerar resposta
4. Job coleta histórico e gera resposta via LLM
5. Cria mensagem outgoing com resposta

## Especificações do AI Agent

### Funcionalidades do AI Agent (Substituto do Captain)

1. **Agent Bot Integration**: Quando cria assistente, automaticamente cria um Agent Bot
2. **Auto-Assignment**: Novas conversas na inbox são automaticamente assigned para o Agent Bot quando ele esta registrado na caixa
3. **Auto-Response**: Responde sempre que está assigned (não só quando pending)
4. **Sistema Independente**: Namespace `ai_agent_*` próprio
5. **Sidebar Própria**: Atalho dedicado na navegação
6. **Simplicidade**: Foco apenas em auto-resposta, sem complexidades enterprise

### Estrutura de Tabelas Proposta

```sql
-- Assistentes AI Agent
CREATE TABLE ai_agent_assistants (
  id BIGINT PRIMARY KEY,
  name VARCHAR NOT NULL,
  description TEXT,
  config JSONB NOT NULL,
  guardrails JSONB,
  response_guidelines JSONB,
  account_id BIGINT NOT NULL,
  agent_bot_id BIGINT, -- Referência ao Agent Bot criado
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Relacionamento Assistant <-> Inbox
CREATE TABLE ai_agent_inboxes (
  id BIGINT PRIMARY KEY,
  ai_agent_assistant_id BIGINT NOT NULL,
  inbox_id BIGINT NOT NULL,
  auto_assign BOOLEAN DEFAULT true,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  UNIQUE(inbox_id) -- Garante que cada inbox só pode ter um AI Agent
);



-- Respostas/embeddings
CREATE TABLE ai_agent_responses (
  id BIGINT PRIMARY KEY,
  question VARCHAR NOT NULL,
  answer TEXT NOT NULL,
  embedding VECTOR(1536),
  assistant_id BIGINT NOT NULL,
  account_id BIGINT NOT NULL,
  status VARCHAR DEFAULT 'active',
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### Models Necessários

```ruby
# app/models/ai_agent/assistant.rb
class AiAgent::Assistant < ApplicationRecord
  self.table_name = 'ai_agent_assistants'
  
  belongs_to :account
  belongs_to :agent_bot, optional: true
  has_many :ai_agent_inboxes, dependent: :destroy
  has_many :inboxes, through: :ai_agent_inboxes
  has_many :responses, class_name: 'AiAgent::Response'
  
  after_create :create_agent_bot
  
  private
  
  def create_agent_bot
    bot = account.agent_bots.create!(
      name: "AI Agent: #{name}",
      description: "Auto-generated bot for AI Agent: #{name}",
      bot_type: 'ai_agent'
    )
    update!(agent_bot: bot)
  end
end

# app/models/ai_agent_inbox.rb
class AiAgentInbox < ApplicationRecord
  belongs_to :ai_agent_assistant, class_name: 'AiAgent::Assistant'
  belongs_to :inbox

  validates :inbox_id, uniqueness: true
  after_create :setup_agent_bot_inbox
  
  private
  
  def setup_agent_bot_inbox
    return unless ai_agent_assistant.agent_bot
    
    inbox.agent_bot_inboxes.find_or_create_by(
      agent_bot: ai_agent_assistant.agent_bot
    )
  end
end
```

### Listeners e Jobs

```ruby
# app/listeners/ai_agent_listener.rb
class AiAgentListener < BaseListener
  include ::Events::Types

  def conversation_created(event)
    conversation = extract_conversation_and_account(event)[0]
    return unless should_auto_assign?(conversation)
    
    ai_agent_assistant = conversation.inbox.ai_agent_assistant
    return unless ai_agent_assistant&.agent_bot
    
    conversation.update!(assignee: ai_agent_assistant.agent_bot)
  end

  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless should_respond?(message)
    
    AiAgent::Conversation::ResponseBuilderJob.perform_later(
      message.conversation,
      message.conversation.inbox.ai_agent_assistant
    )
  end

  private

  def should_auto_assign?(conversation)
    conversation.assignee.blank? && 
    conversation.inbox.ai_agent_assistant.present? &&
    conversation.inbox.ai_agent_inboxes.where(auto_assign: true).exists?
  end

  def should_respond?(message)
    return false unless message.incoming?
    return false unless message.conversation.assignee.is_a?(AgentBot)
    return false unless message.conversation.assignee.bot_type == 'ai_agent'
    
    ai_agent_assistant = message.conversation.inbox.ai_agent_assistant
    ai_agent_assistant.present? && ai_agent_assistant.agent_bot == message.conversation.assignee
  end
end

# app/jobs/ai_agent/conversation/response_builder_job.rb
class AiAgent::Conversation::ResponseBuilderJob < ApplicationJob
  queue_as :default

  def perform(conversation, assistant)
    @conversation = conversation
    @assistant = assistant
    
    generate_and_process_response
  end

  private

  def generate_and_process_response
    response = AiAgent::Llm::AssistantChatService.new(
      assistant: @assistant
    ).generate_response(
      message_history: collect_previous_messages
    )

    create_outgoing_message(response['response'])
  end

  def collect_previous_messages
    @conversation
      .messages
      .where(message_type: [:incoming, :outgoing])
      .where(private: false)
      .map do |message|
      {
        content: message.content,
        role: message.message_type == 'incoming' ? 'user' : 'assistant'
      }
    end
  end

  def create_outgoing_message(content)
    @conversation.messages.create!(
      content: content,
      message_type: :outgoing,
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      sender: @assistant.agent_bot
    )
  end
end
```

### Controllers

```ruby
# app/controllers/api/v1/accounts/ai_agent/assistants_controller.rb
class Api::V1::Accounts::AiAgent::AssistantsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action :set_assistant, only: [:show, :update, :destroy]

  def index
    @assistants = account_assistants.includes(:agent_bot).ordered
  end

  def show; end

  def create
    @assistant = account_assistants.create!(assistant_params)
  end

  def update
    @assistant.update!(assistant_params)
  end

  def destroy
    @assistant.destroy
    head :no_content
  end

  private

  def account_assistants
    current_account.ai_agent_assistants
  end

  def assistant_params
    params.require(:assistant).permit(:name, :description, config: {}, guardrails: {})
  end

  def set_assistant
    @assistant = account_assistants.find(params[:id])
  end
end
```

### Frontend - Sidebar Integration

```javascript
// app/javascript/dashboard/routes/dashboard/ai_agent/ai_agent.routes.js
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { frontendURL } from '../../../helper/URLHelper';
import AssistantIndex from './assistants/Index.vue';
import AssistantEdit from './assistants/Edit.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/ai-agent/assistants'),
    component: AssistantIndex,
    name: 'ai_agent_assistants_index',
    meta: {
      permissions: ['administrator', 'agent'],
      featureFlag: FEATURE_FLAGS.AI_AGENT,
    },
  },
  {
    path: frontendURL('accounts/:accountId/ai-agent/assistants/:assistantId'),
    component: AssistantEdit,
    name: 'ai_agent_assistants_edit',
    meta: {
      permissions: ['administrator', 'agent'],
      featureFlag: FEATURE_FLAGS.AI_AGENT,
    },
  },
];
```

### Sidebar Update

```javascript
// Adicionar ao app/javascript/dashboard/components-next/sidebar/Sidebar.vue
{
  name: 'AI Agent',
  icon: 'i-lucide-bot',
  label: t('SIDEBAR.AI_AGENT'),
  children: [
    {
      name: 'Assistants',
      label: t('SIDEBAR.AI_AGENT_ASSISTANTS'),
      to: accountScopedRoute('ai_agent_assistants_index'),
    },
  ],
},
```

## Tarefas de Implementação

### Fase 1: Estrutura Base
1. [x] Criar migration para tabelas AI Agent
2. [x] Implementar models básicos
3. [x] Criar controllers API
4. [x] Implementar views JSON

### Fase 2: Integração com Agent Bot
1. [x] Modificar AgentBot para suportar tipo 'ai_agent'
2. [x] Implementar criação automática de Agent Bot
3. [x] Configurar relacionamento Assistant <-> AgentBot

### Fase 3: Auto-Assignment
1. [x] Implementar AiAgentListener
2. [x] Configurar auto-assignment em conversation_created
3. [x] Testar fluxo de atribuição automática

### Fase 4: Auto-Response
1. [x] Implementar ResponseBuilderJob
2. [x] Criar serviço de chat LLM
3. [x] Configurar resposta automática em message_created

### Fase 5: Frontend
1. [x] Criar componentes Vue para gerenciar assistentes
2. [x] Implementar interface de configuração
3. [x] Adicionar atalho na sidebar
4. [x] Implementar rotas frontend

### Fase 6: Integração com Pagamentos
1. [ ] Remover Captain dos limites de billing
2. [ ] Adicionar AI Agent aos limites de billing
3. [ ] Atualizar Enterprise::Account::PlanUsageAndLimits
4. [ ] Migrar métodos de usage tracking
5. [ ] Implementar sistema de pacotes avulsos
6. [ ] Criar produtos Stripe para pacotes de respostas
7. [ ] Atualizar billing services
8. [ ] Atualizar frontend de billing

### Fase 7: Testes
1. [ ] Testes unitários para models
2. [ ] Testes de integração para listeners
3. [ ] Testes de API
4. [ ] Testes E2E do fluxo completo
5. [ ] Testes de billing e usage tracking

## Integração com Sistema de Pagamentos

### Estrutura Atual do Captain (Para Remoção)

**Constantes de Billing:**
```ruby
CAPTAIN_RESPONSES = 'captain_responses'.freeze
CAPTAIN_DOCUMENTS = 'captain_documents'.freeze
CAPTAIN_RESPONSES_USAGE = 'captain_responses_usage'.freeze
CAPTAIN_DOCUMENTS_USAGE = 'captain_documents_usage'.freeze
```

**Métodos de Usage Tracking:**
- `increment_response_usage` - Incrementa uso de respostas
- `reset_response_usage` - Reseta uso mensal
- `update_document_usage` - Atualiza contagem de documentos
- `get_captain_limits` - Calcula limites disponíveis

### Nova Estrutura AI Agent (Para Implementação)

**Constantes de Billing:**
```ruby
AI_AGENT_RESPONSES = 'ai_agent_responses'.freeze
AI_AGENT_RESPONSES_USAGE = 'ai_agent_responses_usage'.freeze
AI_AGENT_ADDON_RESPONSES = 'ai_agent_addon_responses'.freeze
AI_AGENT_ADDON_RESPONSES_USAGE = 'ai_agent_addon_responses_usage'.freeze
```

**Métodos de Usage Tracking:**
```ruby
def increment_ai_agent_response_usage
  # Primeiro tenta usar quota mensal
  monthly_available = get_ai_agent_monthly_limits[:current_available]

  if monthly_available > 0
    current_usage = custom_attributes[AI_AGENT_RESPONSES_USAGE].to_i || 0
    custom_attributes[AI_AGENT_RESPONSES_USAGE] = current_usage + 1
  else
    # Se não tem quota mensal, usa respostas avulsas
    addon_usage = custom_attributes[AI_AGENT_ADDON_RESPONSES_USAGE].to_i || 0
    custom_attributes[AI_AGENT_ADDON_RESPONSES_USAGE] = addon_usage + 1
  end

  save
end

def reset_ai_agent_response_usage
  custom_attributes[AI_AGENT_RESPONSES_USAGE] = 0
  save
end

def add_ai_agent_addon_responses(quantity)
  current_addon = custom_attributes[AI_AGENT_ADDON_RESPONSES].to_i || 0
  custom_attributes[AI_AGENT_ADDON_RESPONSES] = current_addon + quantity
  save
end

def get_ai_agent_monthly_limits
  total_count = ai_agent_monthly_limit.to_i
  consumed = custom_attributes[AI_AGENT_RESPONSES_USAGE].to_i || 0

  {
    total_count: total_count,
    current_available: (total_count - consumed).clamp(0, total_count),
    consumed: consumed
  }
end

def get_ai_agent_addon_limits
  total_addon = custom_attributes[AI_AGENT_ADDON_RESPONSES].to_i || 0
  consumed_addon = custom_attributes[AI_AGENT_ADDON_RESPONSES_USAGE].to_i || 0

  {
    total_count: total_addon,
    current_available: (total_addon - consumed_addon).clamp(0, total_addon),
    consumed: consumed_addon
  }
end

def get_ai_agent_total_available
  monthly_available = get_ai_agent_monthly_limits[:current_available]
  addon_available = get_ai_agent_addon_limits[:current_available]

  monthly_available + addon_available
end
```

**Atualização do usage_limits:**
```ruby
def usage_limits
  {
    agents: agent_limits.to_i,
    inboxes: get_limits(:inboxes).to_i,
    ai_agent: {
      monthly_responses: get_ai_agent_monthly_limits,
      addon_responses: get_ai_agent_addon_limits,
      total_available: get_ai_agent_total_available
    }
  }
end
```

**Frontend para Compra de Pacotes:**
```vue
<!-- app/javascript/dashboard/routes/dashboard/settings/billing/AiAgentAddonPackages.vue -->
<template>
  <div class="ai-agent-addon-packages">
    <div class="current-usage">
      <h3>Uso Atual de Respostas AI Agent</h3>
      <div class="usage-cards">
        <div class="usage-card">
          <h4>Quota Mensal</h4>
          <p>{{ monthlyLimits.consumed }} / {{ monthlyLimits.totalCount }}</p>
          <div class="progress-bar">
            <div
              class="progress-fill"
              :style="{ width: monthlyUsagePercentage + '%' }"
            ></div>
          </div>
        </div>

        <div class="usage-card">
          <h4>Respostas Avulsas</h4>
          <p>{{ addonLimits.consumed }} / {{ addonLimits.totalCount }}</p>
          <div class="progress-bar">
            <div
              class="progress-fill addon"
              :style="{ width: addonUsagePercentage + '%' }"
            ></div>
          </div>
        </div>
      </div>
    </div>

    <div class="addon-packages">
      <h3>Comprar Pacotes de Respostas Avulsas</h3>
      <div class="packages-grid">
        <div
          v-for="package in availablePackages"
          :key="package.id"
          class="package-card"
          :class="{ recommended: package.id === 'medium' }"
        >
          <div class="package-header">
            <h4>{{ package.name }}</h4>
            <span v-if="package.id === 'medium'" class="recommended-badge">
              Recomendado
            </span>
          </div>

          <div class="package-details">
            <div class="responses-count">
              {{ package.responses.toLocaleString() }} respostas
            </div>
            <div class="price">
              ${{ (package.price / 100).toFixed(2) }}
            </div>
            <div class="price-per-response">
              ${{ (package.price / 100 / package.responses).toFixed(4) }} por resposta
            </div>
          </div>

          <button
            @click="purchasePackage(package)"
            :disabled="purchasing"
            class="purchase-btn"
          >
            {{ purchasing ? 'Processando...' : 'Comprar Agora' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useAccount } from 'dashboard/composables/useAccount';

const store = useStore();
const { currentAccount } = useAccount();

const availablePackages = ref([]);
const purchasing = ref(false);

const aiAgentLimits = computed(() => {
  return currentAccount.value?.limits?.ai_agent || {};
});

const monthlyLimits = computed(() => {
  return aiAgentLimits.value.monthly_responses || { consumed: 0, totalCount: 0 };
});

const addonLimits = computed(() => {
  return aiAgentLimits.value.addon_responses || { consumed: 0, totalCount: 0 };
});

const monthlyUsagePercentage = computed(() => {
  if (monthlyLimits.value.totalCount === 0) return 0;
  return (monthlyLimits.value.consumed / monthlyLimits.value.totalCount) * 100;
});

const addonUsagePercentage = computed(() => {
  if (addonLimits.value.totalCount === 0) return 0;
  return (addonLimits.value.consumed / addonLimits.value.totalCount) * 100;
});

const fetchPackages = async () => {
  try {
    const response = await store.dispatch('aiAgent/fetchAddonPackages');
    availablePackages.value = response.data;
  } catch (error) {
    console.error('Error fetching packages:', error);
  }
};

const purchasePackage = async (package) => {
  purchasing.value = true;
  try {
    const response = await store.dispatch('aiAgent/purchaseAddonPackage', {
      packageId: package.id
    });

    // Redirecionar para Stripe Checkout
    window.location.href = response.data.checkout_url;
  } catch (error) {
    console.error('Error purchasing package:', error);
    purchasing.value = false;
  }
};

onMounted(() => {
  fetchPackages();
});
</script>
```

### Arquivos que Precisam ser Atualizados

1. **enterprise/app/models/enterprise/account/plan_usage_and_limits.rb**
   - Remover constantes e métodos do Captain
   - Adicionar constantes e métodos do AI Agent

2. **enterprise/app/services/enterprise/billing/handle_stripe_event_service.rb**
   - Atualizar `reset_captain_usage` para `reset_ai_agent_usage`

3. **app/javascript/dashboard/composables/useCaptain.js**
   - Renomear para `useAiAgent.js`
   - Atualizar referências de captain para ai_agent

4. **Frontend de Billing**
   - Atualizar interfaces para mostrar limites do AI Agent
   - Remover referências ao Captain
   - Adicionar interface para compra de pacotes avulsos

### Sistema de Pacotes Avulsos

**Produtos Stripe Sugeridos:**
- **Pacote Pequeno**: 100 respostas - $9.99
- **Pacote Médio**: 500 respostas - $39.99
- **Pacote Grande**: 1000 respostas - $69.99
- **Pacote Empresarial**: 5000 respostas - $299.99

**Fluxo de Compra:**
1. Cliente acessa página de billing
2. Visualiza quota mensal atual e respostas avulsas disponíveis
3. Seleciona pacote de respostas avulsas
4. Checkout via Stripe
5. Webhook do Stripe adiciona respostas à conta

**Lógica de Consumo (Prioridade):**
1. **Primeira prioridade**: Quota mensal do plano
2. **Segunda prioridade**: Respostas avulsas compradas
3. **Bloqueio**: Quando ambas esgotam

**Controller para Compra de Pacotes:**
```ruby
# app/controllers/api/v1/accounts/ai_agent/addon_packages_controller.rb
class Api::V1::Accounts::AiAgent::AddonPackagesController < Api::V1::Accounts::BaseController
  def index
    # Lista pacotes disponíveis
    render json: available_packages
  end

  def create
    # Cria sessão de checkout no Stripe
    package = find_package(params[:package_id])
    session = create_stripe_checkout_session(package)
    render json: { checkout_url: session.url }
  end

  private

  def available_packages
    [
      { id: 'small', name: 'Pacote Pequeno', responses: 100, price: 999 },
      { id: 'medium', name: 'Pacote Médio', responses: 500, price: 3999 },
      { id: 'large', name: 'Pacote Grande', responses: 1000, price: 6999 },
      { id: 'enterprise', name: 'Pacote Empresarial', responses: 5000, price: 29999 }
    ]
  end
end
```

**Webhook Handler para Pacotes:**
```ruby
# enterprise/app/services/enterprise/billing/handle_addon_purchase_service.rb
class Enterprise::Billing::HandleAddonPurchaseService
  def initialize(stripe_event)
    @stripe_event = stripe_event
    @session = stripe_event.data.object
  end

  def perform
    return unless @session.payment_status == 'paid'

    account = find_account_by_customer_id(@session.customer)
    package_info = extract_package_info(@session.metadata)

    account.add_ai_agent_addon_responses(package_info[:responses])

    Rails.logger.info "Added #{package_info[:responses]} addon responses to account #{account.id}"
  end

  private

  def extract_package_info(metadata)
    {
      responses: metadata['responses'].to_i,
      package_name: metadata['package_name']
    }
  end
end
```

## Considerações Técnicas

### Diferenças de Implementação
- **Auto-Assignment**: Usar `conversation_created` em vez de status `pending`
- **Agent Bot Integration**: Criar bot automaticamente e usar como assignee
- **Namespace Separado**: `AiAgent::` para evitar conflitos
- **Feature Flag**: `AI_AGENT` separada do `CAPTAIN`
- **Billing Integration**: Sistema próprio de usage tracking

### Substituição do Captain
- **Descontinuação**: Captain será descontinuado por ser ferramenta enterprise
- **Substituição Completa**: AI Agent assume todas as funcionalidades de auto-resposta
- **Migração de Billing**: Sistema de cobrança migra do Captain para AI Agent

### Pontos de Atenção
- Validar permissões adequadas
- Implementar rate limiting para respostas
- Considerar fallback para handoff manual
- Monitorar performance das respostas automáticas
- Garantir estabilidade do sistema de auto-assignment
- Interface intuitiva para configuração
- **Migração de Billing**: Garantir transição suave do sistema de cobrança
- **Usage Tracking**: Manter precisão na contabilização de uso
- **Limites de Plano**: Respeitar quotas mensais configuradas
- **Pacotes Avulsos**: Garantir ordem correta de consumo (mensal → avulso)
- **Stripe Integration**: Validar webhooks e produtos corretamente
- **UX de Compra**: Interface clara para compra de pacotes adicionais

Este planejamento fornece uma base sólida para implementar o AI Agent como substituto completo do Captain, criando um sistema mais simples, focado e eficiente de auto-assignment e resposta automática.
