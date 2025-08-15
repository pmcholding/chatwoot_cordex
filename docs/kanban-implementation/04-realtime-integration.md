# Kanban System - Real-time & WebSocket Integration

## Overview

This guide provides the complete real-time implementation for the Chatwoot Kanban System. This covers ActionCable integration, WebSocket event handling, and real-time state synchronization.

**Implementation Priority:** 🟡 High (Week 3-4)  
**Dependencies:** [Shard 2 - Backend Core](./02-backend-core.md), [Shard 3 - Frontend Components](./03-frontend-components.md)  
**Target Audience:** Full-stack Team, DevOps

---

## ActionCable Integration

### Kanban Channel

```ruby
# app/channels/kanban_channel.rb
class KanbanChannel < ApplicationCable::Channel
  def subscribed
    ensure_confirmation_sent
    
    # Verify account access
    account = Account.find(params[:account_id])
    authorize account, :show?
    
    stream_from "account_#{account.id}_kanban"
  end

  def unsubscribed
    # Cleanup when channel is unsubscribed
  end

  private

  def authorize(record, action)
    policy = Pundit.policy(current_user, record)
    raise Pundit::NotAuthorizedError unless policy.public_send(action)
  end
end
```

### Real-time Event Broadcasting

```ruby
# app/models/concerns/kanban_broadcastable.rb
module KanbanBroadcastable
  extend ActiveSupport::Concern

  included do
    after_commit :broadcast_kanban_change, on: [:create, :update, :destroy]
  end

  private

  def broadcast_kanban_change
    return unless saved_changes.any? || destroyed?
    
    ActionCable.server.broadcast(
      kanban_channel_name,
      kanban_broadcast_data
    )
  end

  def kanban_channel_name
    "account_#{account_id}_kanban"
  end

  def kanban_broadcast_data
    {
      type: kanban_event_type,
      model: self.class.name.underscore,
      id: id,
      data: kanban_serialized_data
    }
  end

  def kanban_event_type
    case
    when destroyed? then 'destroyed'
    when previously_new_record? then 'created'
    else 'updated'
    end
  end

  def kanban_serialized_data
    # Override in including models
    {}
  end
end
```

---

## Frontend WebSocket Integration

### Kanban Real-time Composable

```javascript
// app/javascript/dashboard/composables/useKanbanRealtime.js
import { ref, onMounted, onUnmounted } from 'vue'
import { useStore } from 'vuex'

export function useKanbanRealtime(accountId) {
  const store = useStore()
  const isConnected = ref(false)
  const connectionError = ref(null)
  let subscription = null

  function connect() {
    if (subscription) {
      subscription.unsubscribe()
    }

    subscription = App.cable.subscriptions.create(
      { 
        channel: 'KanbanChannel', 
        account_id: accountId 
      },
      {
        connected() {
          isConnected.value = true
          connectionError.value = null
          console.log('Connected to Kanban channel')
        },

        disconnected() {
          isConnected.value = false
          console.log('Disconnected from Kanban channel')
        },

        received(data) {
          handleRealtimeEvent(data)
        },

        rejected() {
          connectionError.value = 'Connection rejected'
          console.error('Kanban channel connection rejected')
        }
      }
    )
  }

  function handleRealtimeEvent(data) {
    switch (data.type) {
      case 'stage_created':
        store.commit('kanban/ADD_KANBAN_STAGE', data.stage)
        break
        
      case 'stage_updated':
        store.commit('kanban/UPDATE_KANBAN_STAGE', data.stage)
        break
        
      case 'stage_destroyed':
        store.commit('kanban/REMOVE_KANBAN_STAGE', data.stage_id)
        break
        
      case 'conversation_stage_changed':
        store.commit('kanban/MOVE_CONVERSATION_BETWEEN_STAGES', {
          conversationId: data.conversation_id,
          oldStageId: data.old_stage_id,
          newStageId: data.new_stage_id,
          conversation: data.conversation
        })
        break
        
      case 'conversation_updated':
        store.commit('kanban/UPDATE_CONVERSATION_IN_STAGE', {
          conversation: data.conversation
        })
        break
        
      default:
        console.warn('Unknown realtime event type:', data.type)
    }
  }

  function disconnect() {
    if (subscription) {
      subscription.unsubscribe()
      subscription = null
    }
    isConnected.value = false
  }

  onMounted(() => {
    connect()
  })

  onUnmounted(() => {
    disconnect()
  })

  return {
    isConnected,
    connectionError,
    connect,
    disconnect
  }
}
```

### Connection Status Component

```vue
<!-- app/javascript/dashboard/components/KanbanConnectionStatus.vue -->
<template>
  <div 
    class="connection-status"
    :class="statusClass"
  >
    <Icon :name="statusIcon" size="16" />
    <span class="status-text">{{ statusText }}</span>
    <button 
      v-if="showReconnect"
      @click="reconnect"
      class="reconnect-btn"
    >
      Reconnect
    </button>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  isConnected: {
    type: Boolean,
    required: true
  },
  connectionError: {
    type: String,
    default: null
  }
})

const emit = defineEmits(['reconnect'])

const statusClass = computed(() => ({
  'connected': props.isConnected,
  'disconnected': !props.isConnected && !props.connectionError,
  'error': !!props.connectionError
}))

const statusIcon = computed(() => {
  if (props.connectionError) return 'alert-circle'
  return props.isConnected ? 'check-circle' : 'clock'
})

const statusText = computed(() => {
  if (props.connectionError) return 'Connection failed'
  return props.isConnected ? 'Real-time updates active' : 'Connecting...'
})

const showReconnect = computed(() => {
  return !props.isConnected || props.connectionError
})

function reconnect() {
  emit('reconnect')
}
</script>

<style scoped>
.connection-status {
  @apply flex items-center gap-2 px-3 py-2 rounded-lg text-sm;
}

.connection-status.connected {
  @apply bg-green-100 text-green-800;
}

.connection-status.disconnected {
  @apply bg-yellow-100 text-yellow-800;
}

.connection-status.error {
  @apply bg-red-100 text-red-800;
}

.reconnect-btn {
  @apply text-xs underline hover:no-underline;
}
</style>
```

---

## Event Types & Payloads

### Stage Events

#### Stage Created
```json
{
  "type": "stage_created",
  "stage": {
    "id": 123,
    "name": "New Stage",
    "color": "#3b82f6",
    "position": 5,
    "conversations_count": 0
  }
}
```

#### Stage Updated
```json
{
  "type": "stage_updated",
  "stage": {
    "id": 123,
    "name": "Updated Stage Name",
    "color": "#10b981",
    "position": 5,
    "conversations_count": 3
  }
}
```

#### Stage Destroyed
```json
{
  "type": "stage_destroyed",
  "stage_id": 123
}
```

### Conversation Events

#### Conversation Stage Changed
```json
{
  "type": "conversation_stage_changed",
  "conversation_id": 456,
  "old_stage_id": 123,
  "new_stage_id": 124,
  "conversation": {
    "id": 456,
    "subject": "Customer inquiry",
    "kanban_stage_id": 124,
    "contact": {
      "name": "John Doe"
    }
  }
}
```

#### Conversation Updated
```json
{
  "type": "conversation_updated",
  "conversation": {
    "id": 456,
    "subject": "Updated subject",
    "status": "resolved",
    "kanban_stage_id": 124
  }
}
```

---

## Backend Event Broadcasting

### Enhanced KanbanStage Model

```ruby
# app/models/kanban_stage.rb (real-time additions)
class KanbanStage < ApplicationRecord
  include KanbanBroadcastable
  
  # ... existing code ...
  
  private
  
  def kanban_serialized_data
    KanbanStageSerializer.new(self, include_conversations_count: true).serializable_hash
  end
end
```

### Enhanced Conversation Model

```ruby
# app/models/conversation.rb (real-time additions)
class Conversation < ApplicationRecord
  include KanbanBroadcastable
  
  # ... existing code ...
  
  private
  
  def kanban_serialized_data
    ConversationSerializer.new(self, include_associations: true).serializable_hash
  end
  
  def should_broadcast_kanban_change?
    # Only broadcast if kanban-related fields changed
    saved_changes.keys.intersect?(%w[kanban_stage_id status assignee_id])
  end
  
  def broadcast_kanban_change
    return unless should_broadcast_kanban_change?
    super
  end
end
```

---

## Frontend Event Handling

### Enhanced Vuex Store Mutations

```javascript
// app/javascript/dashboard/store/modules/kanban.js (real-time additions)

const mutations = {
  // ... existing mutations ...

  [types.MOVE_CONVERSATION_BETWEEN_STAGES](state, { conversationId, oldStageId, newStageId, conversation }) {
    // Remove from old stage
    if (oldStageId && state.conversationsByStage[oldStageId]) {
      state.conversationsByStage[oldStageId] = state.conversationsByStage[oldStageId]
        .filter(c => c.id !== conversationId)
    }
    
    // Add to new stage
    if (newStageId) {
      if (!state.conversationsByStage[newStageId]) {
        state.conversationsByStage[newStageId] = []
      }
      
      // Check if conversation already exists (avoid duplicates)
      const existingIndex = state.conversationsByStage[newStageId]
        .findIndex(c => c.id === conversationId)
      
      if (existingIndex === -1) {
        state.conversationsByStage[newStageId].unshift(conversation)
      } else {
        // Update existing conversation
        state.conversationsByStage[newStageId][existingIndex] = conversation
      }
    }
  },

  [types.UPDATE_CONVERSATION_IN_STAGE](state, { conversation }) {
    const stageId = conversation.kanban_stage_id
    
    if (stageId && state.conversationsByStage[stageId]) {
      const index = state.conversationsByStage[stageId]
        .findIndex(c => c.id === conversation.id)
      
      if (index !== -1) {
        state.conversationsByStage[stageId][index] = conversation
      }
    }
  },

  [types.ROLLBACK_CONVERSATION_MOVE](state, { conversationId, targetStageId, sourceStageId }) {
    // This is the reverse of MOVE_CONVERSATION_OPTIMISTIC
    const targetConversations = state.conversationsByStage[targetStageId] || []
    const conversation = targetConversations.find(c => c.id === conversationId)
    
    if (conversation) {
      // Remove from target
      state.conversationsByStage[targetStageId] = targetConversations
        .filter(c => c.id !== conversationId)
      
      // Add back to source
      if (!state.conversationsByStage[sourceStageId]) {
        state.conversationsByStage[sourceStageId] = []
      }
      state.conversationsByStage[sourceStageId].unshift(conversation)
    }
  }
}
```

---

## Connection Management

### Reconnection Strategy

```javascript
// app/javascript/dashboard/composables/useKanbanRealtime.js (enhanced)
export function useKanbanRealtime(accountId) {
  const store = useStore()
  const isConnected = ref(false)
  const connectionError = ref(null)
  const reconnectAttempts = ref(0)
  const maxReconnectAttempts = 5
  let subscription = null
  let reconnectTimer = null

  function connect() {
    if (subscription) {
      subscription.unsubscribe()
    }

    subscription = App.cable.subscriptions.create(
      { 
        channel: 'KanbanChannel', 
        account_id: accountId 
      },
      {
        connected() {
          isConnected.value = true
          connectionError.value = null
          reconnectAttempts.value = 0
          console.log('Connected to Kanban channel')
          
          // Refresh data on reconnection
          if (reconnectAttempts.value > 0) {
            store.dispatch('kanban/fetchStages')
            store.dispatch('kanban/fetchConversations', { reset: true })
          }
        },

        disconnected() {
          isConnected.value = false
          console.log('Disconnected from Kanban channel')
          scheduleReconnect()
        },

        received(data) {
          handleRealtimeEvent(data)
        },

        rejected() {
          connectionError.value = 'Connection rejected'
          console.error('Kanban channel connection rejected')
          scheduleReconnect()
        }
      }
    )
  }

  function scheduleReconnect() {
    if (reconnectAttempts.value >= maxReconnectAttempts) {
      connectionError.value = 'Maximum reconnection attempts reached'
      return
    }

    const delay = Math.min(1000 * Math.pow(2, reconnectAttempts.value), 30000)
    reconnectAttempts.value++

    reconnectTimer = setTimeout(() => {
      console.log(`Attempting to reconnect (${reconnectAttempts.value}/${maxReconnectAttempts})`)
      connect()
    }, delay)
  }

  function forceReconnect() {
    reconnectAttempts.value = 0
    connectionError.value = null
    
    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = null
    }
    
    connect()
  }

  function disconnect() {
    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = null
    }
    
    if (subscription) {
      subscription.unsubscribe()
      subscription = null
    }
    
    isConnected.value = false
    reconnectAttempts.value = 0
  }

  return {
    isConnected,
    connectionError,
    reconnectAttempts,
    connect,
    disconnect,
    forceReconnect
  }
}
```

---

## Conflict Resolution

### Optimistic Update Conflicts

```javascript
// app/javascript/dashboard/composables/useOptimisticUpdates.js
import { ref } from 'vue'

export function useOptimisticUpdates() {
  const pendingOperations = ref(new Map())

  function applyOptimisticUpdate(operationId, updateFn, rollbackFn) {
    // Store rollback function for potential reversal
    pendingOperations.value.set(operationId, rollbackFn)
    
    // Apply optimistic update immediately
    updateFn()
    
    return {
      confirm() {
        pendingOperations.value.delete(operationId)
      },
      
      rollback() {
        const rollback = pendingOperations.value.get(operationId)
        if (rollback) {
          rollback()
          pendingOperations.value.delete(operationId)
        }
      }
    }
  }

  function rollbackAll() {
    pendingOperations.value.forEach(rollbackFn => rollbackFn())
    pendingOperations.value.clear()
  }

  return {
    applyOptimisticUpdate,
    rollbackAll,
    hasPendingOperations: computed(() => pendingOperations.value.size > 0)
  }
}
```

### Server-side Conflict Detection

```ruby
# app/controllers/concerns/kanban_conflict_resolution.rb
module KanbanConflictResolution
  extend ActiveSupport::Concern
  
  private
  
  def handle_conversation_stage_conflict(conversation, new_stage_id)
    # Check if conversation was modified by another user
    if conversation.updated_at > 5.seconds.ago
      render json: {
        error: 'Conversation was recently modified by another user',
        current_stage_id: conversation.kanban_stage_id,
        last_modified: conversation.updated_at
      }, status: :conflict
      return false
    end
    
    true
  end
  
  def broadcast_conflict_resolution(conversation, conflicting_user)
    ActionCable.server.broadcast(
      "account_#{conversation.account_id}_kanban",
      {
        type: 'conflict_detected',
        conversation_id: conversation.id,
        conflicting_user: conflicting_user.name,
        current_stage_id: conversation.kanban_stage_id
      }
    )
  end
end
```

---

## Performance Optimization

### Event Throttling

```javascript
// app/javascript/dashboard/utils/eventThrottling.js
export function throttleEvents(eventHandler, delay = 100) {
  let lastEventTime = 0
  let timeoutId = null
  
  return function(event) {
    const now = Date.now()
    
    if (now - lastEventTime >= delay) {
      // Execute immediately if enough time has passed
      lastEventTime = now
      eventHandler(event)
    } else {
      // Throttle the event
      if (timeoutId) {
        clearTimeout(timeoutId)
      }
      
      timeoutId = setTimeout(() => {
        lastEventTime = Date.now()
        eventHandler(event)
      }, delay - (now - lastEventTime))
    }
  }
}
```

### Selective Event Broadcasting

```ruby
# app/models/concerns/selective_broadcasting.rb
module SelectiveBroadcasting
  extend ActiveSupport::Concern
  
  def broadcast_to_kanban_users_only
    users_in_kanban = account.users.joins(:active_sessions)
                              .where(active_sessions: { current_page: '/kanban' })
    
    if users_in_kanban.any?
      ActionCable.server.broadcast(
        "account_#{account_id}_kanban",
        kanban_broadcast_data
      )
    end
  end
end
```

---

## Implementation Checklist

### Backend Integration
- [ ] Create KanbanChannel for ActionCable
- [ ] Add broadcasting concerns to models
- [ ] Implement event payload serialization
- [ ] Add conflict detection mechanisms
- [ ] Test real-time broadcasting

### Frontend Integration
- [ ] Create real-time composable
- [ ] Implement WebSocket event handlers
- [ ] Add connection status indicators
- [ ] Build reconnection logic
- [ ] Handle optimistic update conflicts

### Event Management
- [ ] Define all event types and payloads
- [ ] Implement event throttling
- [ ] Add selective broadcasting
- [ ] Test event ordering and delivery
- [ ] Handle edge cases and failures

### Performance & Reliability
- [ ] Add connection monitoring
- [ ] Implement automatic reconnection
- [ ] Handle network failures gracefully
- [ ] Test with multiple concurrent users
- [ ] Monitor WebSocket performance

---

## Integration Points

**Dependencies:**
- ✅ Requires [Backend Core](./02-backend-core.md) models and controllers
- ✅ Requires [Frontend Components](./03-frontend-components.md) Vuex store

**Next Steps:**
- 🔄 **Performance Optimization**: Real-time events ready for [Performance Optimization](./06-performance-optimization.md)
- 🔄 **Testing**: Real-time functionality ready for [Testing Implementation](./07-testing-guide.md)

**Related Documents:**
- [Backend Core Implementation](./02-backend-core.md)
- [Frontend Components Guide](./03-frontend-components.md)
- [Performance Optimization Guide](./06-performance-optimization.md)
- [Testing Guide](./07-testing-guide.md)