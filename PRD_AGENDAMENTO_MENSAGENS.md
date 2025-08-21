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

## 🎨 Estados Visuais (Tailwind Only)

### Caixa de Mensagem - Classes Tailwind
```vue
<!-- Estado padrão -->
<div class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-600 rounded-lg">

<!-- Estado agendado -->
<div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-700 rounded-lg">
```

### Indicador de Data/Hora na Caixa
```vue
<div
  v-if="isScheduled"
  class="flex items-center justify-between text-xs text-blue-600 dark:text-blue-400 px-3 py-2 border-b border-blue-200 dark:border-blue-700 bg-blue-50/50 dark:bg-blue-900/10"
>
  <span class="flex items-center gap-1">
    <i class="i-ph-clock text-sm"></i>
    {{ $t('CONVERSATION.FOOTER.SCHEDULED_FOR') }}: {{ formatDateTime(scheduledDateTime) }}
  </span>
  <button
    @click="cancelSchedule"
    class="text-red-500 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300 transition-colors"
    :title="$t('CONVERSATION.FOOTER.CANCEL_SCHEDULE')"
  >
    <i class="i-ph-x text-sm"></i>
  </button>
</div>
```

## 📱 Interface da Mensagem Agendada na Conversa

### Estrutura no `.conversation-panel` (Tailwind Only)
```vue
<div class="bg-blue-50 dark:bg-blue-900/20 border-l-4 border-blue-400 p-3 mb-2 rounded-r-lg shadow-sm">
  <div class="flex items-center justify-between mb-2">
    <span class="text-sm text-blue-600 dark:text-blue-400 font-medium flex items-center gap-1">
      <i class="i-ph-clock text-sm"></i>
      {{ $t('CONVERSATION.SCHEDULED_MESSAGE.TITLE') }}
    </span>
    <button
      @click="cancelScheduledMessage"
      class="text-red-500 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300 text-xs px-2 py-1 rounded hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
    >
      {{ $t('CONVERSATION.SCHEDULED_MESSAGE.CANCEL') }}
    </button>
  </div>
  <p class="text-slate-800 dark:text-slate-200 mb-2">{{ messageContent }}</p>
  <p class="text-xs text-blue-500 dark:text-blue-400 flex items-center gap-1">
    <i class="i-ph-calendar text-xs"></i>
    {{ $t('CONVERSATION.SCHEDULED_MESSAGE.WILL_BE_SENT') }}: {{ formatDateTime(scheduledDateTime) }}
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

### ⚡ Estratégia: Usar tabela `messages` existente com status `scheduled: 4`

**DECISÃO ARQUITETURAL FINAL:**
- ✅ **Usar tabela `messages` existente** em vez de criar `scheduled_messages` separada
- ✅ **Adicionar `scheduled: 4`** ao enum status
- ✅ **Manter `created_at`** como timestamp real de criação
- ✅ **Usar `additional_attributes['scheduled_at']`** para data de agendamento
- ✅ **Usar `additional_attributes['display_at']`** para controlar onde aparece na timeline
- ✅ **Modificar `send_reply`** para não enviar mensagens com status `scheduled`

**JUSTIFICATIVA:**
- 🎯 **Alinhado com Chatwoot**: Simplicidade > Over-engineering
- 🎯 **UX superior**: Timeline unificada, mensagens agendadas aparecem naturalmente
- 🎯 **Menos código**: ~70% menos linhas que tabela separada
- 🎯 **Performance adequada**: Para volume esperado de agendamentos
- 🎯 **Manutenção simples**: Uma fonte de verdade

### Frontend (Vue 3 + Composition API)

#### ReplyBox.vue - Composition API Implementation
```vue
<script setup>
import { ref, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import ScheduleDatePicker from './ScheduleDatePicker.vue'

const { t } = useI18n()

// Reactive state
const isScheduled = ref(false)
const scheduledDateTime = ref(null)
const showSchedulePicker = ref(false)

// Computed properties
const scheduleTooltip = computed(() =>
  isScheduled.value
    ? t('CONVERSATION.FOOTER.CANCEL_SCHEDULE')
    : t('CONVERSATION.FOOTER.SCHEDULE_MESSAGE')
)

const replyBoxClasses = computed(() => ({
  'bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-700': isScheduled.value,
  'bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-600': !isScheduled.value
}))

// Methods
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

const formatDateTime = (dateTime) => {
  if (!dateTime) return ''
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  }).format(new Date(dateTime))
}
</script>
```

### Backend (Rails)

#### Model: `Message` (Modificado)
```ruby
# app/models/message.rb
class Message < ApplicationRecord
  # Adicionar scheduled ao enum existente
  enum status: { sent: 0, delivered: 1, read: 2, failed: 3, scheduled: 4 }
  
  # Scopes para agendamento
  scope :scheduled, -> { where(status: :scheduled) }
  scope :ready_to_send, -> { 
    scheduled.where("(additional_attributes->>'scheduled_at')::timestamp <= ?", Time.current) 
  }
  
  # Métodos para agendamento
  def schedule_for(datetime)
    self.status = :scheduled
    self.additional_attributes = (additional_attributes || {}).merge(
      'scheduled_at' => datetime.iso8601,
      'display_at' => datetime.iso8601
    )
  end
  
  # Getters para timestamps
  def scheduled_at
    Time.parse(additional_attributes['scheduled_at']) if additional_attributes['scheduled_at']
  end
  
  def display_timestamp
    scheduled? ? Time.parse(additional_attributes['display_at']) : created_at
  end
  
  # Override push_event_data para usar display_timestamp na UI
  def push_event_data
    data = attributes.symbolize_keys.merge(
      created_at: display_timestamp.to_i, # ← Usar display_timestamp
      message_type: message_type_before_type_cast,
      conversation_id: conversation.display_id,
      conversation: conversation_push_event_data
    )
    # ... resto igual
  end
  
  private
  
  # Modificar método existente para não enviar mensagens agendadas
  def send_reply
    return if scheduled? # ← Nova linha para bloquear envio
    
    # FIXME: Giving it few seconds for the attachment to be uploaded to the service
    # active storage attaches the file only after commit
    attachments.blank? ? ::SendReplyJob.perform_later(id) : ::SendReplyJob.set(wait: 2.seconds).perform_later(id)
  end
end
```

#### Migration:
```ruby
class AddScheduledStatusToMessages < ActiveRecord::Migration[7.0]
  def up
    # O valor 4 será mapeado para 'scheduled' automaticamente pelo ActiveRecord
    # Não precisa alterar a coluna, apenas usar o novo valor
    
    # Adicionar índice para performance do background job
    add_index :messages, [
      :status, 
      "(additional_attributes->>'scheduled_at')"
    ], 
    name: 'index_messages_on_status_and_scheduled_at',
    where: "status = 4" # Apenas mensagens agendadas
  end
  
  def down
    remove_index :messages, name: 'index_messages_on_status_and_scheduled_at'
    
    # Converter mensagens agendadas para enviadas (fallback)
    Message.where(status: 4).update_all(status: 0)
  end
end
```

#### Background Job:
```ruby
class ScheduledMessageJob < ApplicationJob
  queue_as :default
  
  def perform
    Message.ready_to_send.find_each do |message|
      begin
        # Simplesmente atualizar status para 'sent'
        # Isso dispara o send_reply automaticamente via callback after_update_commit
        message.update!(status: :sent)
        
        Rails.logger.info "Scheduled message #{message.id} sent successfully at #{Time.current}"
      rescue => e
        message.update!(status: :failed)
        Rails.logger.error "Failed to send scheduled message #{message.id}: #{e.message}"
      end
    end
  end
end
```

#### Controller: `Api::V1::Accounts::Conversations::ScheduledMessagesController`
```ruby
class Api::V1::Accounts::Conversations::ScheduledMessagesController < Api::V1::Accounts::BaseController
  before_action :set_conversation
  
  def create
    # Criar mensagem normal, mas com status scheduled
    @message = @conversation.messages.build(message_params)
    @message.account = Current.account
    @message.inbox = @conversation.inbox
    @message.sender = Current.user
    @message.message_type = :outgoing
    
    # Definir como agendada
    @message.schedule_for(Time.parse(params[:scheduled_at]))
    
    if @message.save
      render json: {
        message: @message.as_json,
        scheduled_at: @message.scheduled_at,
        display_at: @message.display_timestamp
      }
    else
      render json: { errors: @message.errors }, status: :unprocessable_entity
    end
  end
  
  def index
    # Listar mensagens agendadas da conversa
    @scheduled_messages = @conversation.messages.scheduled
                                      .includes(:sender, :attachments)
                                      .order(created_at: :desc)
    render json: @scheduled_messages.map { |msg|
      msg.as_json.merge(
        scheduled_at: msg.scheduled_at,
        display_at: msg.display_timestamp
      )
    }
  end
  
  def destroy
    # Cancelar mensagem agendada
    @message = @conversation.messages.scheduled.find(params[:id])
    @message.update!(status: :failed) # Marca como cancelada
    head :no_content
  end
  
  private
  
  def set_conversation
    @conversation = Current.account.conversations.find(params[:conversation_id])
  end
  
  def message_params
    params.require(:message).permit(:content, :private, content_attributes: {})
  end
end
```

### Banco de Dados

**Uso da tabela `messages` existente (sem alterações estruturais):**

```sql
-- Schema atual da tabela messages permanece inalterado
-- O campo status aceita valores 0-4:
-- 0: sent, 1: delivered, 2: read, 3: failed, 4: scheduled

-- O campo additional_attributes (JSONB) armazenará:
-- {
--   "scheduled_at": "2025-08-21T15:30:00Z",  -- Quando deve ser enviada
--   "display_at": "2025-08-21T15:30:00Z",    -- Quando deve aparecer na timeline
--   "campaign_id": "...",                   -- Outros dados existentes
--   "outros_dados": "..."
-- }

-- Novo índice para performance do background job:
CREATE INDEX index_messages_on_status_and_scheduled_at 
ON messages(status, (additional_attributes->>'scheduled_at'))
WHERE status = 4;

-- Índices existentes já cobrem outras necessidades:
-- - index_messages_on_conversation_id (para listar por conversa)
-- - index_messages_on_account_id (para escopo de conta)
-- - index_messages_on_created_at (para ordenação cronológica)
-- - default_scope { order(created_at: :asc) } (ordenação automática)
```

## 📝 Implementações Completas dos Componentes

### ScheduleDatePicker.vue - Implementação Completa
```vue
<script setup>
import { ref, computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'

const { t } = useI18n()

const props = defineProps({
  show: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['close', 'confirm'])

// Reactive state
const selectedDate = ref('')
const selectedTime = ref('')
const isValid = ref(false)

// Computed properties
const minDate = computed(() => {
  const tomorrow = new Date()
  tomorrow.setDate(tomorrow.getDate() + 1)
  return tomorrow.toISOString().split('T')[0]
})

const minTime = computed(() => {
  const now = new Date()
  const today = now.toISOString().split('T')[0]

  if (selectedDate.value === today) {
    const hours = String(now.getHours()).padStart(2, '0')
    const minutes = String(now.getMinutes() + 5).padStart(2, '0') // 5 min buffer
    return `${hours}:${minutes}`
  }
  return '00:00'
})

// Methods
const validateDateTime = () => {
  if (!selectedDate.value || !selectedTime.value) {
    isValid.value = false
    return
  }

  const selectedDateTime = new Date(`${selectedDate.value}T${selectedTime.value}`)
  const now = new Date()

  isValid.value = selectedDateTime > now
}

const handleConfirm = () => {
  if (!isValid.value) return

  const dateTime = new Date(`${selectedDate.value}T${selectedTime.value}`)
  emit('confirm', dateTime.toISOString())
}

const handleClose = () => {
  selectedDate.value = ''
  selectedTime.value = ''
  isValid.value = false
  emit('close')
}

// Watchers
watch([selectedDate, selectedTime], validateDateTime)

// Initialize with tomorrow
onMounted(() => {
  const tomorrow = new Date()
  tomorrow.setDate(tomorrow.getDate() + 1)
  selectedDate.value = tomorrow.toISOString().split('T')[0]
  selectedTime.value = '09:00'
  validateDateTime()
})
</script>

<template>
  <div
    v-if="show"
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
    @click.self="handleClose"
  >
    <div class="bg-white dark:bg-slate-800 rounded-lg shadow-xl p-6 w-full max-w-md mx-4">
      <h3 class="text-lg font-semibold text-slate-800 dark:text-slate-200 mb-4">
        {{ t('CONVERSATION.FOOTER.SELECT_DATE_TIME') }}
      </h3>

      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
            {{ t('CONVERSATION.FOOTER.DATE') }}
          </label>
          <input
            v-model="selectedDate"
            type="date"
            :min="minDate"
            class="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-200 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
            {{ t('CONVERSATION.FOOTER.TIME') }}
          </label>
          <input
            v-model="selectedTime"
            type="time"
            :min="minTime"
            class="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-200 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
        </div>
      </div>

      <div class="flex justify-end gap-3 mt-6">
        <button
          @click="handleClose"
          class="px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200 transition-colors"
        >
          {{ t('CONVERSATION.FOOTER.CANCEL') }}
        </button>
        <button
          @click="handleConfirm"
          :disabled="!isValid"
          class="px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 disabled:bg-slate-300 disabled:cursor-not-allowed rounded-md transition-colors"
        >
          {{ t('CONVERSATION.FOOTER.CONFIRM') }}
        </button>
      </div>
    </div>
  </div>
</template>
```

### API Integration - scheduledMessage.js
```javascript
import ApiClient from '../ApiClient'

class ScheduledMessageAPI extends ApiClient {
  constructor() {
    super('scheduled_messages', { accountScoped: true })
  }

  create(conversationId, messageData) {
    return axios.post(
      `${this.apiVersion}/accounts/${this.accountId}/conversations/${conversationId}/scheduled_messages`,
      messageData
    )
  }

  list(conversationId) {
    return axios.get(
      `${this.apiVersion}/accounts/${this.accountId}/conversations/${conversationId}/scheduled_messages`
    )
  }

  cancel(conversationId, messageId) {
    return axios.delete(
      `${this.apiVersion}/accounts/${this.accountId}/conversations/${conversationId}/scheduled_messages/${messageId}`
    )
  }
}

export default new ScheduledMessageAPI()
```

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

## 🌐 Internacionalização (i18n) - Completa

### Frontend - `en.json` (Chaves Completas):
```json
{
  "CONVERSATION": {
    "FOOTER": {
      "SCHEDULE_MESSAGE": "Schedule message",
      "CANCEL_SCHEDULE": "Cancel schedule",
      "SCHEDULED_FOR": "Scheduled for",
      "SELECT_DATE_TIME": "Select date and time",
      "DATE": "Date",
      "TIME": "Time",
      "CANCEL": "Cancel",
      "CONFIRM": "Confirm"
    },
    "SCHEDULED_MESSAGE": {
      "TITLE": "Scheduled",
      "WILL_BE_SENT": "Will be sent on",
      "CANCEL": "Cancel",
      "CANCELLED": "Cancelled",
      "SUCCESS": "Message scheduled successfully",
      "FAILED": "Failed to schedule message"
    },
    "ERRORS": {
      "INVALID_SCHEDULE_TIME": "Scheduled time must be in the future",
      "SCHEDULE_LIMIT_EXCEEDED": "Maximum number of scheduled messages exceeded",
      "SCHEDULE_PERMISSION_DENIED": "You don't have permission to schedule messages",
      "FAILED_TO_SCHEDULE_MESSAGE": "Failed to schedule message"
    }
  }
}
```

### Backend - `en.yml` (Para logs e validações):
```yaml
en:
  activerecord:
    errors:
      models:
        message:
          attributes:
            scheduled_at:
              invalid: "must be in the future"
              blank: "can't be blank for scheduled messages"

  scheduled_messages:
    job:
      success: "Scheduled message %{id} sent successfully"
      failed: "Failed to send scheduled message %{id}: %{error}"

    validations:
      invalid_time: "Scheduled time must be in the future"
      limit_exceeded: "Maximum scheduled messages limit exceeded"
      permission_denied: "User does not have permission to schedule messages"
```

## ⚡ Performance & Optimization

### Database Performance
```sql
-- Índice otimizado para o background job
CREATE INDEX CONCURRENTLY index_messages_on_status_and_scheduled_at
ON messages(status, (additional_attributes->>'scheduled_at'))
WHERE status = 4;

-- Índice para listagem por conversa
CREATE INDEX CONCURRENTLY index_messages_on_conversation_scheduled
ON messages(conversation_id, status, created_at)
WHERE status = 4;
```

### Background Job Optimization
```ruby
# app/jobs/scheduled_message_job.rb
class ScheduledMessageJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # Processar em batches para evitar memory issues
    Message.ready_to_send.find_in_batches(batch_size: 100) do |batch|
      batch.each do |message|
        process_scheduled_message(message)
      end
    end
  end

  private

  def process_scheduled_message(message)
    # Usar transaction para atomicidade
    Message.transaction do
      message.update!(status: :sent)
    end
  rescue => e
    # Log error mas não falhar o job inteiro
    Rails.logger.error "Failed to send scheduled message #{message.id}: #{e.message}"
    message.update!(status: :failed) rescue nil
  end
end
```

### Frontend Performance
```vue
<script setup>
// Debounce para validação de data/hora
import { debounce } from 'lodash-es'

const validateDateTime = debounce(() => {
  // validação logic
}, 300)

// Lazy loading do componente ScheduleDatePicker
const ScheduleDatePicker = defineAsyncComponent(() =>
  import('./ScheduleDatePicker.vue')
)
</script>
```

## 🔧 Configuração de Deploy Completa

### 1. Background Job Configuration
```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq

# Configurar queue específica para scheduled jobs
config.active_job.queue_name_prefix = Rails.env
```

### 2. Sidekiq Configuration
```ruby
# config/sidekiq.yml
:queues:
  - default
  - scheduled_jobs
  - mailers

# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end
```

### 3. Cron Job Setup (sidekiq-cron)
```ruby
# config/initializers/sidekiq.rb
if Sidekiq.server?
  Sidekiq::Cron::Job.create(
    name: 'Process Scheduled Messages',
    cron: '* * * * *', # Every minute
    class: 'ScheduledMessageJob'
  )
end
```

### 4. Alternative: Whenever Gem
```ruby
# Gemfile
gem 'whenever', require: false

# config/schedule.rb
every 1.minute do
  runner "ScheduledMessageJob.perform_later"
end

# Deploy command
whenever --update-crontab
```

### 5. Environment Variables
```bash
# .env
REDIS_URL=redis://localhost:6379/0
SCHEDULED_MESSAGES_ENABLED=true
SCHEDULED_MESSAGES_BATCH_SIZE=100
SCHEDULED_MESSAGES_MAX_PER_CONVERSATION=50
```

### 6. Monitoring & Alerts
```ruby
# config/initializers/scheduled_messages.rb
Rails.application.config.after_initialize do
  # Configurar alertas para mensagens falhadas
  if Rails.env.production?
    Sidekiq.configure_server do |config|
      config.error_handlers << proc do |ex, ctx|
        if ctx['class'] == 'ScheduledMessageJob'
          # Enviar alerta para Slack/email
          Rails.logger.error "ScheduledMessageJob failed: #{ex.message}"
        end
      end
    end
  end
end
```

## 🚨 Error Handling & Custom Exceptions

### Custom Exceptions (seguindo padrão Chatwoot)
```ruby
# lib/custom_exceptions/scheduled_message_exceptions.rb
module CustomExceptions::ScheduledMessage
  class InvalidScheduleTime < CustomExceptions::Base
    def message
      'Scheduled time must be in the future'
    end
  end

  class ScheduleLimitExceeded < CustomExceptions::Base
    def message
      'Maximum number of scheduled messages exceeded for this conversation'
    end
  end

  class SchedulePermissionDenied < CustomExceptions::Base
    def message
      'User does not have permission to schedule messages'
    end
  end
end
```

### Error Handling no Controller
```ruby
# app/controllers/api/v1/accounts/conversations/scheduled_messages_controller.rb
rescue_from CustomExceptions::ScheduledMessage::InvalidScheduleTime do |e|
  render json: { error: e.message }, status: :unprocessable_entity
end

rescue_from CustomExceptions::ScheduledMessage::ScheduleLimitExceeded do |e|
  render json: { error: e.message }, status: :forbidden
end

rescue_from CustomExceptions::ScheduledMessage::SchedulePermissionDenied do |e|
  render json: { error: e.message }, status: :forbidden
end
```

### Frontend Error Handling
```vue
<script setup>
import { useAlert } from '@/composables/useAlert'

const { showAlert } = useAlert()

const handleScheduleError = (error) => {
  const message = error.response?.data?.error || 'Failed to schedule message'
  showAlert({
    type: 'error',
    message: t(`CONVERSATION.ERRORS.${message.toUpperCase()}`) || message
  })
}

const scheduleMessage = async (messageData) => {
  try {
    await ScheduledMessageAPI.create(conversationId, messageData)
    showAlert({
      type: 'success',
      message: t('CONVERSATION.SCHEDULED_MESSAGE.SUCCESS')
    })
  } catch (error) {
    handleScheduleError(error)
  }
}
</script>
```

## 🧪 Testing Strategy (MVP Approach)

### Manual Testing Checklist
```markdown
**Frontend Testing:**
- [ ] Botão relógio toggle funciona
- [ ] Modal abre/fecha corretamente
- [ ] Validação de data/hora futura
- [ ] Estados visuais da caixa de mensagem
- [ ] Responsividade em mobile
- [ ] Modo escuro funciona
- [ ] I18n strings aparecem corretamente

**Backend Testing:**
- [ ] Enum `scheduled: 4` funciona
- [ ] Métodos `schedule_for` e `scheduled_at` funcionam
- [ ] Background job processa mensagens
- [ ] API endpoints respondem corretamente
- [ ] Validações de permissão funcionam
- [ ] Error handling funciona

**Integration Testing:**
- [ ] Fluxo completo: agendar → aparecer no painel → enviar automaticamente
- [ ] Cancelamento de agendamento funciona
- [ ] Performance com múltiplas mensagens agendadas
```

### Automated Testing (apenas se solicitado)
```ruby
# spec/models/message_spec.rb (apenas se necessário)
RSpec.describe Message, type: :model do
  describe '#schedule_for' do
    it 'sets status to scheduled and stores datetime' do
      message = build(:message)
      future_time = 1.hour.from_now

      message.schedule_for(future_time)

      expect(message.status).to eq('scheduled')
      expect(message.scheduled_at).to be_within(1.second).of(future_time)
    end
  end
end
```

## 🚦 Fases de Implementação (MVP Focus)

### Fase 1 - Core MVP (Mínimo Viável):
- [ ] Modificar `Message` model (enum + métodos + send_reply)
- [ ] Botão toggle de agendamento no ReplyBottomPanel
- [ ] Modal básico de data/hora (ScheduleDatePicker)
- [ ] Estado visual da caixa agendada (ReplyBox)
- [ ] Background job (ScheduledMessageJob)
- [ ] Controller API (ScheduledMessagesController)
- [ ] Migration (índice para performance)
- [ ] Error handling básico
- [ ] I18n strings essenciais

### Fase 2 - UX Improvements:
- [ ] Mensagens agendadas no painel
- [ ] Cancelamento de agendamentos
- [ ] Validações avançadas
- [ ] Feedback visual melhorado

### Fase 3 - Production Ready:
- [ ] Performance optimization
- [ ] Logs e monitoramento
- [ ] Testes automatizados (se solicitado)
- [ ] Interface mobile refinada

## 🛣️ Routes Configuration

### API Routes (`config/routes.rb`)
```ruby
Rails.application.routes.draw do
  namespace :api, defaults: { format: 'json' } do
    namespace :v1 do
      resources :accounts do
        resources :conversations do
          resources :scheduled_messages, only: [:index, :create, :destroy]
        end
      end
    end
  end
end
```

### Frontend Routes (se necessário)
```javascript
// app/javascript/dashboard/routes/dashboard/conversation/routes.js
{
  path: 'scheduled',
  name: 'conversation_scheduled_messages',
  component: () => import('../components/ScheduledMessagesList.vue'),
  meta: { permissions: ['conversation_manage'] }
}
```

## 📋 Lista Completa de Arquivos

### 🆕 Novos Arquivos a Criar:
1. **`app/javascript/dashboard/components/widgets/ScheduleDatePicker.vue`** - Modal de seleção de data/hora
2. **`app/javascript/dashboard/api/inbox/scheduledMessage.js`** - API client para agendamentos
3. **`app/jobs/scheduled_message_job.rb`** - Background job para envio
4. **`app/controllers/api/v1/accounts/conversations/scheduled_messages_controller.rb`** - Controller da API
5. **`db/migrate/xxx_add_scheduled_status_to_messages.rb`** - Migration para índices
6. **`lib/custom_exceptions/scheduled_message_exceptions.rb`** - Custom exceptions
7. **`config/initializers/scheduled_messages.rb`** - Configurações e monitoramento

### ✏️ Arquivos a Modificar:
1. **`app/models/message.rb`**
   - Adicionar `scheduled: 4` ao enum status
   - Métodos `schedule_for`, `scheduled_at`, `display_timestamp`
   - Modificar `send_reply` para não enviar mensagens agendadas

2. **`app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue`**
   - Adicionar botão relógio após botão de assinatura (linha ~334)
   - Props e eventos para agendamento

3. **`app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue`**
   - Estados visuais para modo agendado
   - Indicador de data/hora agendada
   - Classes Tailwind condicionais

4. **`app/javascript/dashboard/components/widgets/conversation/MessagesView.vue`**
   - Exibir mensagens agendadas com visual diferenciado
   - Botão de cancelamento para mensagens agendadas

5. **`config/routes.rb`**
   - Rotas da API para scheduled_messages

6. **`app/jobs/trigger_scheduled_items_job.rb`**
   - Adicionar chamada para `ScheduledMessageJob.perform_later`

7. **`app/javascript/dashboard/i18n/locale/en.json`**
   - Adicionar todas as chaves de i18n necessárias

8. **`config/locales/en.yml`**
   - Adicionar chaves para validações e logs

## 🎯 Critérios de Aceitação Finais

### ✅ Funcionalidades Core:
- [ ] Botão relógio toggle agendamento on/off
- [ ] Modal/popover para seleção de data/hora com validação
- [ ] Caixa de mensagem muda cor quando agendado (Tailwind only)
- [ ] Data/hora aparecem na caixa quando agendado com i18n
- [ ] Possível cancelar agendamento antes do envio
- [ ] Mensagem agendada aparece no painel com horário futuro
- [ ] Background job executa envio automaticamente
- [ ] Validação: não permitir datas passadas
- [ ] Error handling com custom exceptions

### ✅ Qualidade & Performance:
- [ ] Responsivo: funciona em mobile
- [ ] Acessibilidade: tooltips e navegação por teclado
- [ ] Performance: índices otimizados para queries
- [ ] Logs estruturados para monitoramento
- [ ] I18n completo (en.json + en.yml)
- [ ] Seguir guidelines do CLAUDE.md (Tailwind only, Composition API, MVP focus)

### ✅ Segurança & Robustez:
- [ ] Validar permissões do usuário para agendar mensagens
- [ ] Sanitizar conteúdo da mensagem
- [ ] Limitar quantidade de mensagens agendadas por conversa
- [ ] Log de ações para auditoria
- [ ] Error handling graceful sem quebrar a aplicação

---

## 🚀 Ready for Implementation!

Este PRD está completo e alinhado com as diretrizes do CLAUDE.md:
- ✅ **MVP Focus**: Mínimas mudanças de código, happy-path only
- ✅ **Tailwind Only**: Sem CSS customizado, apenas utility classes
- ✅ **Composition API**: Todos os componentes Vue com `<script setup>`
- ✅ **I18n**: Sem strings hardcoded, tudo internacionalizado
- ✅ **Error Handling**: Custom exceptions seguindo padrão Chatwoot
- ✅ **Performance**: Índices otimizados e background jobs eficientes
- ✅ **Testing Strategy**: Manual testing + automated apenas se solicitado