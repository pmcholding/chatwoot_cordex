# Kanban System - Performance & Optimization

## Overview

This guide provides comprehensive performance optimization strategies for the Chatwoot Kanban System. This covers backend caching, frontend virtual scrolling, database optimization, and real-time performance enhancements.

**Implementation Priority:** 🟢 Medium (Week 4-5)  
**Dependencies:** [Shard 2 - Backend Core](./02-backend-core.md), [Shard 3 - Frontend Components](./03-frontend-components.md)  
**Target Audience:** Backend Team, DevOps

---

## Backend Caching Strategy

### Redis Caching Service

```ruby
# app/services/kanban_cache_service.rb
class KanbanCacheService
  include Service::Base
  
  CACHE_PREFIX = 'kanban'
  DEFAULT_TTL = 15.minutes
  BOARD_TTL = 5.minutes
  STAGE_TTL = 30.minutes

  class << self
    def cache_kanban_board(account, filters = {})
      cache_key = board_cache_key(account.id, filters)
      
      Rails.cache.fetch(cache_key, expires_in: BOARD_TTL) do
        Conversation.kanban_board_data(account, filters)
      end
    end

    def cache_stages_for_account(account)
      cache_key = stages_cache_key(account.id)
      
      Rails.cache.fetch(cache_key, expires_in: STAGE_TTL) do
        account.kanban_stages.ordered.includes(:conversations)
               .map { |stage| KanbanStageSerializer.new(stage, include_conversations_count: true).serializable_hash }
      end
    end

    def invalidate_account_cache(account_id)
      pattern = "#{CACHE_PREFIX}:*:#{account_id}:*"
      Rails.cache.delete_matched(pattern)
    end

    def invalidate_stage_cache(stage)
      invalidate_account_cache(stage.account_id)
      
      # Also invalidate board caches that might include this stage
      pattern = "#{CACHE_PREFIX}:board:#{stage.account_id}:*"
      Rails.cache.delete_matched(pattern)
    end

    def cache_stage_conversations(stage, filters = {})
      cache_key = stage_conversations_key(stage.id, filters)
      
      Rails.cache.fetch(cache_key, expires_in: DEFAULT_TTL) do
        conversations = stage.conversations
                            .includes(:contact, :assignee, :labels, :inbox)
                            .kanban_ordered
                            .limit(50)
        
        conversations.map { |c| ConversationSerializer.new(c, include_associations: true).serializable_hash }
      end
    end

    def warm_cache_for_account(account)
      # Pre-warm frequently accessed data
      cache_stages_for_account(account)
      cache_kanban_board(account)
      
      # Pre-warm conversations for each stage
      account.kanban_stages.each do |stage|
        cache_stage_conversations(stage)
      end
    end

    private

    def board_cache_key(account_id, filters)
      filter_hash = generate_filter_hash(filters)
      "#{CACHE_PREFIX}:board:#{account_id}:#{filter_hash}"
    end

    def stages_cache_key(account_id)
      "#{CACHE_PREFIX}:stages:#{account_id}"
    end

    def stage_conversations_key(stage_id, filters)
      filter_hash = generate_filter_hash(filters)
      "#{CACHE_PREFIX}:stage:#{stage_id}:conversations:#{filter_hash}"
    end

    def generate_filter_hash(filters)
      # Create deterministic hash from filters
      normalized_filters = filters.sort_by { |k, _| k.to_s }.to_h
      Digest::MD5.hexdigest(normalized_filters.to_json)
    end
  end
end
```

### Cache Invalidation Strategy

```ruby
# app/models/concerns/kanban_cache_invalidation.rb
module KanbanCacheInvalidation
  extend ActiveSupport::Concern

  included do
    after_commit :invalidate_kanban_cache, on: [:create, :update, :destroy]
  end

  private

  def invalidate_kanban_cache
    case self.class.name
    when 'KanbanStage'
      handle_stage_cache_invalidation
    when 'Conversation'
      handle_conversation_cache_invalidation
    end
  end

  def handle_stage_cache_invalidation
    KanbanCacheService.invalidate_stage_cache(self)
    
    # Async cache warming for frequently accessed accounts
    if account.users.active.count > 10
      KanbanCacheWarmupJob.perform_later(account.id)
    end
  end

  def handle_conversation_cache_invalidation
    return unless affects_kanban_cache?
    
    # Invalidate caches for both old and new stages
    stages_to_invalidate = [kanban_stage_id, kanban_stage_id_before_last_save].compact.uniq
    
    stages_to_invalidate.each do |stage_id|
      stage = KanbanStage.find_by(id: stage_id)
      KanbanCacheService.invalidate_stage_cache(stage) if stage
    end
  end

  def affects_kanban_cache?
    # Only invalidate if Kanban-related fields changed
    return true if destroyed?
    
    kanban_fields = %w[kanban_stage_id status assignee_id updated_at]
    saved_changes.keys.intersect?(kanban_fields)
  end
end
```

### Background Cache Warming

```ruby
# app/jobs/kanban_cache_warmup_job.rb
class KanbanCacheWarmupJob < ApplicationJob
  queue_as :low_priority
  
  def perform(account_id)
    account = Account.find(account_id)
    
    # Warm up caches during low-traffic periods
    KanbanCacheService.warm_cache_for_account(account)
    
    # Pre-warm common filter combinations
    common_filters = [
      {},
      { status: ['open'] },
      { assignee_ids: account.users.agents.limit(5).pluck(:id) },
      { inbox_ids: account.inboxes.limit(3).pluck(:id) }
    ]
    
    common_filters.each do |filters|
      KanbanCacheService.cache_kanban_board(account, filters)
    end
  end
end
```

---

## Database Query Optimization

### Optimized Query Patterns

```ruby
# app/models/concerns/kanban_queryable.rb (enhanced)
module KanbanQueryable
  extend ActiveSupport::Concern

  class_methods do
    def kanban_board_data(account, filters = {})
      # Use single query with joins instead of N+1
      stages_with_counts = optimized_stages_query(account)
      conversations_data = optimized_conversations_query(account, filters)
      
      {
        stages: stages_with_counts,
        conversations_by_stage: group_conversations_by_stage(conversations_data),
        total_count: conversations_data.count
      }
    end

    private

    def optimized_stages_query(account)
      # Single query to get stages with conversation counts
      account.kanban_stages
             .select('kanban_stages.*, COUNT(conversations.id) as conversations_count')
             .left_joins(:conversations)
             .group('kanban_stages.id')
             .order(:position)
    end

    def optimized_conversations_query(account, filters)
      query = account.conversations
                    .includes(conversation_includes)
                    .joins(conversation_joins)
                    .where(conversation_where_conditions(filters))
                    .order(:kanban_stage_id, :updated_at)
      
      apply_filters_with_indexes(query, filters)
    end

    def conversation_includes
      [
        :contact,
        :assignee,
        :inbox,
        { kanban_stage: :account },
        { labels: :account }
      ]
    end

    def conversation_joins
      # Use LEFT JOIN for optional kanban_stage
      'LEFT JOIN kanban_stages ON conversations.kanban_stage_id = kanban_stages.id'
    end

    def conversation_where_conditions(filters)
      conditions = ['conversations.account_id = ?']
      
      # Add conditions that can use indexes
      if filters[:inbox_ids].present?
        conditions << 'conversations.inbox_id IN (?)'
      end
      
      if filters[:assignee_ids].present?
        conditions << 'conversations.assignee_id IN (?)'
      end
      
      conditions.join(' AND ')
    end

    def apply_filters_with_indexes(query, filters)
      # Apply filters in order of index effectiveness
      query = query.where(inbox_id: filters[:inbox_ids]) if filters[:inbox_ids].present?
      query = query.where(assignee_id: filters[:assignee_ids]) if filters[:assignee_ids].present?
      query = query.where(status: filters[:statuses]) if filters[:statuses].present?
      
      # Apply date filters (indexed)
      if filters[:created_after].present?
        query = query.where('conversations.created_at >= ?', filters[:created_after])
      end
      
      if filters[:created_before].present?
        query = query.where('conversations.created_at <= ?', filters[:created_before])
      end
      
      # Apply expensive filters last
      if filters[:label_ids].present?
        query = apply_label_filter(query, filters[:label_ids])
      end
      
      if filters[:search].present?
        query = apply_search_filter(query, filters[:search])
      end
      
      query
    end

    def apply_label_filter(query, label_ids)
      # Use EXISTS for better performance
      query.where(
        'EXISTS (SELECT 1 FROM label_taggings WHERE label_taggings.conversation_id = conversations.id AND label_taggings.tag_id IN (?))',
        label_ids
      )
    end

    def apply_search_filter(query, search_term)
      # Use full-text search index
      query.where(
        "to_tsvector('english', conversations.subject || ' ' || COALESCE(conversations.content, '')) @@ plainto_tsquery(?)",
        search_term
      )
    end

    def group_conversations_by_stage(conversations)
      grouped = conversations.group_by(&:kanban_stage_id)
      
      # Handle unassigned conversations
      unassigned = grouped.delete(nil) || []
      grouped['unassigned'] = unassigned
      
      grouped
    end
  end
end
```

### Database Connection Optimization

```ruby
# config/database.yml (production optimizations)
production:
  # ... existing config ...
  pool: <%= ENV['DB_POOL_SIZE'] || 25 %>
  checkout_timeout: 5
  reaping_frequency: 10
  dead_connection_timeout: 5
  
  # Query optimization
  prepared_statements: true
  advisory_locks: true
  
  # Connection pooling
  variables:
    statement_timeout: 30s
    lock_timeout: 10s
    idle_in_transaction_session_timeout: 60s
```

---

## Frontend Performance Optimization

### Virtual Scrolling Implementation

```javascript
// app/javascript/dashboard/composables/useVirtualScroll.js (enhanced)
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'

export function useVirtualScroll(items, options = {}) {
  const {
    itemHeight = 120,
    containerHeight = 600,
    buffer = 5,
    overscan = 3
  } = options

  const scrollTop = ref(0)
  const containerRef = ref(null)
  const isScrolling = ref(false)
  let scrollTimer = null

  // Memoized calculations
  const totalHeight = computed(() => items.value.length * itemHeight)
  
  const visibleRange = computed(() => {
    const start = Math.floor(scrollTop.value / itemHeight)
    const visibleCount = Math.ceil(containerHeight / itemHeight)
    
    return {
      start: Math.max(0, start - buffer),
      end: Math.min(items.value.length, start + visibleCount + buffer + overscan)
    }
  })

  const visibleItems = computed(() => {
    const { start, end } = visibleRange.value
    return items.value.slice(start, end).map((item, index) => ({
      ...item,
      index: start + index,
      top: (start + index) * itemHeight
    }))
  })

  const spacerBefore = computed(() => visibleRange.value.start * itemHeight)
  const spacerAfter = computed(() => 
    (items.value.length - visibleRange.value.end) * itemHeight
  )

  // Optimized scroll handler
  function handleScroll(event) {
    scrollTop.value = event.target.scrollTop
    
    // Debounce scroll end detection
    isScrolling.value = true
    clearTimeout(scrollTimer)
    scrollTimer = setTimeout(() => {
      isScrolling.value = false
    }, 150)
  }

  // Intersection observer for better performance
  const observerRef = ref(null)
  
  function setupIntersectionObserver() {
    if (!containerRef.value) return
    
    observerRef.value = new IntersectionObserver(
      (entries) => {
        entries.forEach(entry => {
          const itemElement = entry.target
          const itemIndex = parseInt(itemElement.dataset.index)
          
          if (entry.isIntersecting) {
            // Item is visible
            itemElement.classList.add('visible')
          } else {
            // Item is not visible
            itemElement.classList.remove('visible')
          }
        })
      },
      {
        root: containerRef.value,
        rootMargin: '50px',
        threshold: 0.1
      }
    )
  }

  // Smooth scrolling to item
  function scrollToItem(index) {
    if (!containerRef.value) return
    
    const targetTop = index * itemHeight
    containerRef.value.scrollTo({
      top: targetTop,
      behavior: 'smooth'
    })
  }

  // Performance monitoring
  const renderTime = ref(0)
  
  watch(visibleItems, () => {
    const start = performance.now()
    
    // Use requestAnimationFrame for smooth rendering
    requestAnimationFrame(() => {
      renderTime.value = performance.now() - start
    })
  })

  onMounted(() => {
    if (containerRef.value) {
      containerRef.value.addEventListener('scroll', handleScroll, { 
        passive: true 
      })
      setupIntersectionObserver()
    }
  })

  onUnmounted(() => {
    if (scrollTimer) clearTimeout(scrollTimer)
    
    if (containerRef.value) {
      containerRef.value.removeEventListener('scroll', handleScroll)
    }
    
    if (observerRef.value) {
      observerRef.value.disconnect()
    }
  })

  return {
    containerRef,
    visibleItems,
    visibleRange,
    totalHeight,
    spacerBefore,
    spacerAfter,
    isScrolling,
    scrollToItem,
    renderTime
  }
}
```

### Optimistic Updates with Rollback

```javascript
// app/javascript/dashboard/composables/useOptimisticUpdates.js (enhanced)
import { ref, computed } from 'vue'

export function useOptimisticUpdates() {
  const pendingOperations = ref(new Map())
  const failedOperations = ref(new Set())

  function applyOptimisticUpdate(operationId, updateFn, rollbackFn, options = {}) {
    const { timeout = 10000, retryCount = 0 } = options
    
    // Store operation metadata
    const operation = {
      id: operationId,
      rollbackFn,
      timestamp: Date.now(),
      timeout,
      retryCount
    }
    
    pendingOperations.value.set(operationId, operation)
    
    // Apply optimistic update immediately
    updateFn()
    
    // Set timeout for automatic rollback
    const timeoutId = setTimeout(() => {
      if (pendingOperations.value.has(operationId)) {
        rollback(operationId)
        failedOperations.value.add(operationId)
      }
    }, timeout)
    
    return {
      confirm() {
        clearTimeout(timeoutId)
        pendingOperations.value.delete(operationId)
        failedOperations.value.delete(operationId)
      },
      
      rollback() {
        clearTimeout(timeoutId)
        rollback(operationId)
      },
      
      retry(newUpdateFn) {
        if (operation.retryCount < 3) {
          operation.retryCount++
          failedOperations.value.delete(operationId)
          newUpdateFn()
        }
      }
    }
  }

  function rollback(operationId) {
    const operation = pendingOperations.value.get(operationId)
    if (operation && operation.rollbackFn) {
      operation.rollbackFn()
      pendingOperations.value.delete(operationId)
    }
  }

  function rollbackAll() {
    pendingOperations.value.forEach((operation, operationId) => {
      if (operation.rollbackFn) {
        operation.rollbackFn()
      }
    })
    pendingOperations.value.clear()
    failedOperations.value.clear()
  }

  // Performance metrics
  const metrics = computed(() => ({
    pendingCount: pendingOperations.value.size,
    failedCount: failedOperations.value.size,
    avgPendingTime: calculateAvgPendingTime(),
    successRate: calculateSuccessRate()
  }))

  function calculateAvgPendingTime() {
    if (pendingOperations.value.size === 0) return 0
    
    const now = Date.now()
    const totalTime = Array.from(pendingOperations.value.values())
      .reduce((sum, op) => sum + (now - op.timestamp), 0)
    
    return Math.round(totalTime / pendingOperations.value.size)
  }

  function calculateSuccessRate() {
    const total = pendingOperations.value.size + failedOperations.value.size
    if (total === 0) return 100
    
    return Math.round((1 - failedOperations.value.size / total) * 100)
  }

  return {
    applyOptimisticUpdate,
    rollbackAll,
    hasPendingOperations: computed(() => pendingOperations.value.size > 0),
    hasFailedOperations: computed(() => failedOperations.value.size > 0),
    metrics
  }
}
```

---

## Real-time Performance Optimization

### Efficient Event Broadcasting

```ruby
# app/models/concerns/efficient_broadcasting.rb
module EfficientBroadcasting
  extend ActiveSupport::Concern
  
  included do
    after_commit :broadcast_changes_efficiently, on: [:create, :update, :destroy]
  end
  
  private
  
  def broadcast_changes_efficiently
    return unless should_broadcast?
    
    # Batch broadcasts to reduce ActionCable overhead
    Rails.cache.fetch("broadcast_batch:#{account_id}", expires_in: 100.milliseconds) do
      schedule_batch_broadcast
      true
    end
  end
  
  def should_broadcast?
    return true if destroyed? || previously_new_record?
    
    # Only broadcast significant changes
    significant_changes = saved_changes.keys.intersect?(significant_fields)
    significant_changes.any?
  end
  
  def significant_fields
    case self.class.name
    when 'KanbanStage'
      %w[name color position]
    when 'Conversation'
      %w[kanban_stage_id status assignee_id]
    else
      []
    end
  end
  
  def schedule_batch_broadcast
    # Use a short delay to batch multiple changes
    BroadcastBatchJob.set(wait: 50.milliseconds).perform_later(account_id)
  end
end
```

### WebSocket Connection Optimization

```javascript
// app/javascript/dashboard/composables/useOptimizedWebSocket.js
import { ref, onMounted, onUnmounted } from 'vue'

export function useOptimizedWebSocket(accountId) {
  const isConnected = ref(false)
  const messageQueue = ref([])
  const connectionHealth = ref(100)
  let subscription = null
  let heartbeatInterval = null
  let messageBuffer = []
  let bufferTimeout = null

  function connect() {
    subscription = App.cable.subscriptions.create(
      { channel: 'KanbanChannel', account_id: accountId },
      {
        connected() {
          isConnected.value = true
          connectionHealth.value = 100
          startHeartbeat()
          processQueuedMessages()
        },

        disconnected() {
          isConnected.value = false
          stopHeartbeat()
        },

        received(data) {
          // Buffer messages to reduce DOM thrashing
          messageBuffer.push(data)
          scheduleMessageProcessing()
        }
      }
    )
  }

  function scheduleMessageProcessing() {
    if (bufferTimeout) return
    
    bufferTimeout = setTimeout(() => {
      processBatchedMessages(messageBuffer.splice(0))
      bufferTimeout = null
    }, 16) // ~60fps
  }

  function processBatchedMessages(messages) {
    // Group messages by type for efficient processing
    const groupedMessages = messages.reduce((groups, message) => {
      const type = message.type
      if (!groups[type]) groups[type] = []
      groups[type].push(message)
      return groups
    }, {})

    // Process each group
    Object.entries(groupedMessages).forEach(([type, messages]) => {
      switch (type) {
        case 'conversation_stage_changed':
          processBatchedStageChanges(messages)
          break
        case 'stage_updated':
          processBatchedStageUpdates(messages)
          break
        default:
          messages.forEach(handleSingleMessage)
      }
    })
  }

  function processBatchedStageChanges(messages) {
    // Optimize multiple conversation moves
    const stageChanges = messages.map(msg => ({
      conversationId: msg.conversation_id,
      oldStageId: msg.old_stage_id,
      newStageId: msg.new_stage_id,
      conversation: msg.conversation
    }))

    // Apply all changes in a single commit
    store.commit('kanban/BATCH_MOVE_CONVERSATIONS', stageChanges)
  }

  function startHeartbeat() {
    heartbeatInterval = setInterval(() => {
      if (subscription) {
        const start = performance.now()
        subscription.perform('heartbeat', { timestamp: Date.now() })
        
        // Monitor connection health
        setTimeout(() => {
          const latency = performance.now() - start
          updateConnectionHealth(latency)
        }, 1000)
      }
    }, 30000)
  }

  function updateConnectionHealth(latency) {
    if (latency < 100) {
      connectionHealth.value = Math.min(100, connectionHealth.value + 2)
    } else if (latency > 500) {
      connectionHealth.value = Math.max(0, connectionHealth.value - 10)
    }
  }

  return {
    isConnected,
    connectionHealth,
    connect,
    disconnect: () => {
      if (subscription) {
        subscription.unsubscribe()
        subscription = null
      }
      stopHeartbeat()
    }
  }
}
```

---

## Performance Monitoring

### Backend Performance Tracking

```ruby
# app/controllers/concerns/performance_monitoring.rb
module PerformanceMonitoring
  extend ActiveSupport::Concern
  
  included do
    around_action :monitor_performance, if: :should_monitor?
    after_action :track_response_size
  end
  
  private
  
  def monitor_performance
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    memory_before = memory_usage
    
    yield
    
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    memory_after = memory_usage
    memory_diff = memory_after - memory_before
    
    track_performance_metrics(duration, memory_diff)
  end
  
  def track_performance_metrics(duration, memory_diff)
    metrics = {
      action: "#{controller_name}##{action_name}",
      duration_ms: (duration * 1000).round(2),
      memory_mb: memory_diff.round(2),
      response_size: response.body.bytesize,
      user_id: current_user&.id,
      account_id: Current.account&.id
    }
    
    # Log slow requests
    if duration > 1.0
      Rails.logger.warn("Slow Kanban request: #{metrics.to_json}")
    end
    
    # Send to monitoring service
    MetricsCollector.track('kanban.request', metrics)
    
    # Track in StatsD if available
    if defined?(StatsD)
      StatsD.histogram('kanban.request.duration', duration * 1000, 
                      tags: ["action:#{controller_name}##{action_name}"])
      StatsD.gauge('kanban.request.memory', memory_diff)
    end
  end
  
  def memory_usage
    `ps -o rss -p #{Process.pid}`.strip.split.last.to_i / 1024.0
  rescue
    0
  end
  
  def track_response_size
    size = response.body.bytesize
    
    if size > 1.megabyte
      Rails.logger.warn("Large Kanban response: #{size} bytes for #{request.path}")
    end
  end
  
  def should_monitor?
    # Only monitor in production and for Kanban endpoints
    Rails.env.production? && request.path.include?('kanban')
  end
end
```

### Frontend Performance Metrics

```javascript
// app/javascript/dashboard/utils/performanceTracker.js
class PerformanceTracker {
  constructor() {
    this.metrics = new Map()
    this.observers = []
    this.setupObservers()
  }

  setupObservers() {
    // Measure render performance
    if ('PerformanceObserver' in window) {
      const renderObserver = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (entry.name.includes('kanban')) {
            this.trackMetric('render', entry.duration)
          }
        }
      })
      
      renderObserver.observe({ entryTypes: ['measure'] })
      this.observers.push(renderObserver)
    }

    // Measure network performance
    if (navigator.connection) {
      this.trackMetric('connection', {
        effectiveType: navigator.connection.effectiveType,
        downlink: navigator.connection.downlink,
        rtt: navigator.connection.rtt
      })
    }
  }

  markStart(name) {
    performance.mark(`${name}-start`)
  }

  markEnd(name) {
    performance.mark(`${name}-end`)
    performance.measure(name, `${name}-start`, `${name}-end`)
  }

  trackMetric(name, value) {
    if (!this.metrics.has(name)) {
      this.metrics.set(name, [])
    }
    
    this.metrics.get(name).push({
      value,
      timestamp: Date.now()
    })

    // Keep only last 100 entries
    const entries = this.metrics.get(name)
    if (entries.length > 100) {
      entries.splice(0, entries.length - 100)
    }
  }

  getMetrics() {
    const summary = {}
    
    for (const [name, entries] of this.metrics) {
      if (entries.length === 0) continue
      
      const values = entries.map(e => typeof e.value === 'number' ? e.value : 0)
      summary[name] = {
        count: values.length,
        avg: values.reduce((a, b) => a + b, 0) / values.length,
        min: Math.min(...values),
        max: Math.max(...values),
        latest: entries[entries.length - 1]
      }
    }
    
    return summary
  }

  reportMetrics() {
    const metrics = this.getMetrics()
    
    // Send to analytics
    if (window.gtag) {
      Object.entries(metrics).forEach(([name, data]) => {
        window.gtag('event', 'kanban_performance', {
          metric_name: name,
          metric_value: data.avg,
          custom_parameter: data
        })
      })
    }
    
    console.table(metrics)
  }

  cleanup() {
    this.observers.forEach(observer => observer.disconnect())
    this.metrics.clear()
  }
}

export const performanceTracker = new PerformanceTracker()
```

---

## Implementation Checklist

### Backend Optimization
- [ ] Implement Redis caching service
- [ ] Add cache invalidation strategies
- [ ] Optimize database queries
- [ ] Set up background cache warming
- [ ] Add performance monitoring

### Frontend Optimization
- [ ] Implement virtual scrolling
- [ ] Add optimistic updates with rollback
- [ ] Optimize WebSocket connections
- [ ] Implement performance tracking
- [ ] Add memory leak prevention

### Database Optimization
- [ ] Create optimal indexes
- [ ] Optimize query patterns
- [ ] Implement connection pooling
- [ ] Add query performance monitoring
- [ ] Test with realistic data volumes

### Real-time Optimization
- [ ] Implement efficient broadcasting
- [ ] Add message batching
- [ ] Optimize connection management
- [ ] Monitor WebSocket performance
- [ ] Handle connection failures gracefully

---

## Integration Points

**Dependencies:**
- ✅ Requires [Backend Core](./02-backend-core.md) for models and services
- ✅ Requires [Frontend Components](./03-frontend-components.md) for optimization targets

**Performance Coordination:**
- 🔄 **Testing Performance**: Performance tests in [Testing Implementation](./07-testing-guide.md)
- 🔄 **Deployment Monitoring**: Metrics integration in [Deployment Guide](./08-deployment-monitoring.md)

**Related Documents:**
- [Backend Core Implementation](./02-backend-core.md)
- [Frontend Components Guide](./03-frontend-components.md)
- [Testing Guide](./07-testing-guide.md)
- [Deployment & Monitoring Guide](./08-deployment-monitoring.md)