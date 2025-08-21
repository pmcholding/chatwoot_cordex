# Mini PRD: Agendamento de Mensagens no Chatwoot

## 📋 Visão Geral
Implementar funcionalidade para agendar o envio de mensagens com interface integrada diretamente na caixa de mensagem.

## 🎯 Fluxo de UX Definido

### 1. Estado Inicial
- Botão de relógio (`i-ph-clock`) ao lado do botão de assinatura no `ReplyBottomPanel.vue:329`
- Estado: desabilitado (cor padrão)

### 2. Ativação do Agendamento
- **Click no relógio** → Modal/popover para seleção de data/hora
- **Após seleção** → 
  - Relógio fica com cor ativa (mesma cor dos botões habilitados)
  - Caixa de mensagem muda de cor (fundo diferenciado)
  - Data/hora selecionada aparecem fixas na caixa de mensagem

### 3. Desativação do Agendamento  
- **Click no relógio ativo** → Desabilita agendamento
- Caixa de mensagem volta à cor normal
- Remove indicação de data/hora

### 4. Envio da Mensagem Agendada
- **Click em "Enviar" com agendamento ativo** →
- Mensagem aparece no painel de conversa (`.conversation-panel`) 
- Mostra data/hora futura que será enviada
- Status visual diferenciado (agendada vs enviada)

## 🔧 Componentes a Modificar

### `ReplyBottomPanel.vue`
```vue
<!-- Adicionar após botão de assinatura (linha ~334) -->
<NextButton
  v-if="showScheduleButton"
  v-tooltip.top-end="scheduleTooltip"
  icon="i-ph-clock"
  :slate="!isScheduleActive"
  :blue="isScheduleActive"
  faded
  sm
  @click="toggleScheduleMode"
/>
```

### `ReplyBox.vue` 
- **Estado do agendamento**: `isScheduled`, `scheduledDateTime`
- **Estilo condicional**: classe CSS baseada em `isScheduled`
- **Exibição da data**: componente inline mostrando quando será enviada

### Novo Componente: `ScheduleDatePicker.vue`
- Popover/modal simples com date/time picker
- Botões: "Cancelar", "Confirmar"

## 🎨 Estados Visuais

### Caixa de Mensagem Normal
```css
/* Estado padrão */
.reply-box {
  @apply bg-n-background border-n-slate-6;
}
```

### Caixa de Mensagem Agendada
```css
/* Estado agendado */
.reply-box.scheduled {
  @apply bg-blue-50 border-blue-200 dark:bg-blue-900/20 dark:border-blue-700;
}
```

### Indicador de Data/Hora na Caixa
```vue
<div v-if="isScheduled" class="text-xs text-blue-600 dark:text-blue-400 px-3 py-1 border-b border-blue-200 dark:border-blue-700">
  📅 Agendado para: {{ formatDateTime(scheduledDateTime) }}
  <button @click="cancelSchedule" class="ml-2 text-red-500 hover:text-red-700">
    ✕
  </button>
</div>
```

## 📱 Interface da Mensagem Agendada na Conversa

### Estrutura no `.conversation-panel`
```vue
<div class="scheduled-message bg-blue-50 dark:bg-blue-900/20 border-l-4 border-blue-400 p-3 mb-2 rounded-r-lg">
  <div class="flex items-center justify-between">
    <span class="text-sm text-blue-600 dark:text-blue-400 font-medium flex items-center gap-1">
      <i class="i-ph-clock text-sm"></i>
      Agendado
    </span>
    <button @click="cancelScheduledMessage" class="text-red-500 hover:text-red-700 text-xs">
      Cancelar
    </button>
  </div>
  <p class="mt-2 text-n-slate-12">{{ messageContent }}</p>
  <p class="text-xs text-blue-500 dark:text-blue-400 mt-2">
    Será enviado em: {{ formatDateTime(scheduledDateTime) }}
  </p>
</div>
```

## 🔄 Estados da Funcionalidade

1. **Inativo**: Relógio desabilitado, caixa normal
2. **Selecionando**: Modal/popover aberto para escolha de data/hora
3. **Agendado**: Relógio ativo (azul), caixa colorida, data visível
4. **Enviando**: Mensagem vai para painel com status "agendado"
5. **Executado**: Background job envia e muda status para "enviado"

## 🚀 Implementação Técnica

### Frontend (Vue 3 + Composition API)

#### Props/States necessários no ReplyBox:
```javascript
const isScheduled = ref(false)
const scheduledDateTime = ref(null)
const showSchedulePicker = ref(false)

const scheduleTooltip = computed(() => 
  isScheduled.value 
    ? 'Desativar agendamento' 
    : 'Agendar envio da mensagem'
)

const replyBoxClasses = computed(() => ({
  'scheduled': isScheduled.value
}))
```

#### Métodos principais:
```javascript
const toggleScheduleMode = () => {
  if (isScheduled.value) {
    cancelSchedule()
  } else {
    showSchedulePicker.value = true
  }
}

const setScheduleDateTime = (dateTime) => {
  scheduledDateTime.value = dateTime
  isScheduled.value = true
  showSchedulePicker.value = false
}

const cancelSchedule = () => {
  isScheduled.value = false
  scheduledDateTime.value = null
}
```

### Backend (Rails)

#### Model: `ScheduledMessage`
```ruby
class ScheduledMessage < ApplicationRecord
  belongs_to :conversation
  belongs_to :user
  
  validates :content, presence: true
  validates :scheduled_at, presence: true
  
  enum status: { pending: 0, sent: 1, cancelled: 2, failed: 3 }
  
  scope :ready_to_send, -> { pending.where('scheduled_at <= ?', Time.current) }
end
```

#### Migration:
```ruby
class CreateScheduledMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :scheduled_messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content, null: false
      t.datetime :scheduled_at, null: false
      t.integer :status, default: 0
      t.json :metadata # Para armazenar dados extras (attachments, etc)
      
      t.timestamps
    end
    
    add_index :scheduled_messages, [:status, :scheduled_at]
    add_index :scheduled_messages, :conversation_id
  end
end
```

#### Background Job:
```ruby
class ScheduledMessageJob < ApplicationJob
  queue_as :default
  
  def perform
    ScheduledMessage.ready_to_send.find_each do |scheduled_message|
      begin
        message = scheduled_message.conversation.messages.create!(
          content: scheduled_message.content,
          account: scheduled_message.conversation.account,
          inbox: scheduled_message.conversation.inbox,
          user: scheduled_message.user,
          message_type: :outgoing
        )
        
        scheduled_message.update!(status: :sent)
      rescue => e
        scheduled_message.update!(status: :failed)
        Rails.logger.error "Failed to send scheduled message #{scheduled_message.id}: #{e.message}"
      end
    end
  end
end
```

#### Controller: `Api::V1::ScheduledMessagesController`
```ruby
class Api::V1::ScheduledMessagesController < Api::V1::BaseController
  before_action :set_conversation
  
  def create
    @scheduled_message = @conversation.scheduled_messages.build(scheduled_message_params)
    @scheduled_message.user = Current.user
    
    if @scheduled_message.save
      render json: @scheduled_message
    else
      render json: { errors: @scheduled_message.errors }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @scheduled_message = @conversation.scheduled_messages.find(params[:id])
    @scheduled_message.update!(status: :cancelled)
    head :no_content
  end
  
  private
  
  def set_conversation
    @conversation = Current.account.conversations.find(params[:conversation_id])
  end
  
  def scheduled_message_params
    params.require(:scheduled_message).permit(:content, :scheduled_at)
  end
end
```

### Banco de Dados

```sql
-- Tabela para mensagens agendadas
CREATE TABLE scheduled_messages (
  id BIGSERIAL PRIMARY KEY,
  conversation_id BIGINT NOT NULL REFERENCES conversations(id),
  user_id BIGINT NOT NULL REFERENCES users(id),
  content TEXT NOT NULL,
  scheduled_at TIMESTAMP NOT NULL,
  status INTEGER DEFAULT 0, -- 0: pending, 1: sent, 2: cancelled, 3: failed
  metadata JSONB, -- Para dados extras
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Índices para performance
CREATE INDEX idx_scheduled_messages_status_scheduled_at ON scheduled_messages(status, scheduled_at);
CREATE INDEX idx_scheduled_messages_conversation_id ON scheduled_messages(conversation_id);
```

## 📝 Arquivos a Criar/Modificar

### Novos Arquivos:
1. `app/javascript/dashboard/components/widgets/ScheduleDatePicker.vue`
2. `app/models/scheduled_message.rb`
3. `app/jobs/scheduled_message_job.rb`
4. `app/controllers/api/v1/scheduled_messages_controller.rb`
5. `db/migrate/xxx_create_scheduled_messages.rb`

### Arquivos a Modificar:
1. `app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue`
2. `app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue`
3. `config/routes.rb` (adicionar rotas da API)
4. `config/schedule.rb` (cron job se usar whenever gem)

## 🎯 Critérios de Aceitação

- [ ] Botão relógio toggle agendamento on/off
- [ ] Modal/popover para seleção de data/hora
- [ ] Caixa de mensagem muda cor quando agendado
- [ ] Data/hora aparecem na caixa quando agendado  
- [ ] Possível cancelar agendamento antes do envio
- [ ] Mensagem agendada aparece no painel com horário futuro
- [ ] Background job executa envio automaticamente
- [ ] Validação: não permitir datas passadas
- [ ] Responsivo: funciona em mobile
- [ ] Acessibilidade: tooltips e navegação por teclado

## 🔒 Considerações de Segurança

- Validar permissões do usuário para agendar mensagens
- Sanitizar conteúdo da mensagem
- Limitar quantidade de mensagens agendadas por usuário/conversa
- Log de ações para auditoria

## 🌐 Internacionalização (i18n)

### Chaves necessárias no `en.json`:
```json
{
  "CONVERSATION": {
    "FOOTER": {
      "SCHEDULE_MESSAGE": "Schedule message",
      "CANCEL_SCHEDULE": "Cancel schedule",
      "SCHEDULED_FOR": "Scheduled for",
      "SELECT_DATE_TIME": "Select date and time"
    },
    "SCHEDULED_MESSAGE": {
      "TITLE": "Scheduled",
      "WILL_BE_SENT": "Will be sent on",
      "CANCEL": "Cancel",
      "CANCELLED": "Cancelled"
    }
  }
}
```

## 🔧 Configuração de Deploy

### Cron Job (se usar whenever gem):
```ruby
# config/schedule.rb
every 1.minute do
  runner "ScheduledMessageJob.perform_later"
end
```

### Sidekiq (se usar sidekiq):
```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq

# Configurar cron job no sidekiq-cron
```

## 🚦 Fases de Implementação

### Fase 1 - MVP:
- [ ] Botão toggle de agendamento
- [ ] Modal básico de data/hora
- [ ] Estado visual da caixa agendada
- [ ] Backend básico (model + job)

### Fase 2 - Melhorias:
- [ ] Mensagens agendadas no painel
- [ ] Cancelamento de agendamentos
- [ ] Validações e tratamento de erros

### Fase 3 - Otimizações:
- [ ] Performance do background job
- [ ] Interface mobile
- [ ] Logs e monitoramento