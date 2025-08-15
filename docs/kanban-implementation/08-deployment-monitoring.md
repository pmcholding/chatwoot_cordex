# Kanban System - Deployment & Monitoring Guide

## Overview

This guide covers the deployment strategy, monitoring implementation, and operational aspects of the Chatwoot Kanban System. It focuses on gradual rollout, feature flag management, performance monitoring, and production readiness.

**Prerequisites:**
- Complete implementation of shards 01-07
- All tests passing (unit, integration, E2E)
- Performance benchmarks validated
- Security audit completed

**Team Responsibilities:**
- **DevOps Team**: Infrastructure, deployment pipelines, monitoring setup
- **Platform Team**: Feature flags, gradual rollout, performance monitoring
- **Development Teams**: Application health checks, logging integration

## 1. Feature Flag Implementation

### 1.1 Feature Flag Infrastructure

**Flipper Integration:**
```ruby
# Gemfile
gem 'flipper'
gem 'flipper-active_record'
gem 'flipper-ui'

# config/initializers/flipper.rb
Flipper.configure do |config|
  config.adapter { Flipper::Adapters::ActiveRecord.new }
end

# Feature flag definitions
class KanbanFeatureFlags
  KANBAN_ENABLED = 'kanban_enabled'.freeze
  KANBAN_DRAG_DROP = 'kanban_drag_drop'.freeze
  KANBAN_REAL_TIME = 'kanban_real_time'.freeze
  KANBAN_ANALYTICS = 'kanban_analytics'.freeze
end
```

**Feature Flag Helpers:**
```ruby
# app/helpers/kanban_helper.rb
module KanbanHelper
  def kanban_enabled?(account = nil)
    Flipper.enabled?(KanbanFeatureFlags::KANBAN_ENABLED, account)
  end

  def kanban_feature_enabled?(feature, account = nil)
    Flipper.enabled?(feature, account)
  end
end

# app/controllers/application_controller.rb
def kanban_feature_gate(feature)
  unless kanban_feature_enabled?(feature, current_account)
    render json: { error: 'Feature not available' }, status: :forbidden
  end
end
```

**Frontend Feature Flags:**
```javascript
// app/javascript/dashboard/store/modules/kanban.js
export const kanbanFeatureFlags = {
  isKanbanEnabled: () => window.chatwootConfig.enabledFeatures?.kanban,
  isDragDropEnabled: () => window.chatwootConfig.enabledFeatures?.kanbanDragDrop,
  isRealTimeEnabled: () => window.chatwootConfig.enabledFeatures?.kanbanRealTime,
  isAnalyticsEnabled: () => window.chatwootConfig.enabledFeatures?.kanbanAnalytics
};

// Component usage
<template>
  <div v-if="kanbanFeatureFlags.isKanbanEnabled()">
    <KanbanBoard />
  </div>
</template>
```

### 1.2 Gradual Rollout Strategy

**Phase 1: Internal Testing (Week 1)**
- Enable for internal accounts only
- Test core functionality
- Validate performance metrics

**Phase 2: Beta Testing (Week 2-3)**
- Enable for 5% of accounts (whitelisted)
- Monitor error rates and performance
- Collect user feedback

**Phase 3: Gradual Rollout (Week 4-6)**
- Week 4: 25% of accounts
- Week 5: 50% of accounts
- Week 6: 75% of accounts

**Phase 4: Full Rollout (Week 7)**
- Enable for all accounts
- Monitor for 48 hours
- Remove feature flags if stable

## 2. Deployment Pipeline

### 2.1 CI/CD Configuration

**GitHub Actions Workflow:**
```yaml
# .github/workflows/kanban-deployment.yml
name: Kanban System Deployment

on:
  push:
    branches: [develop, main]
    paths: 
      - 'app/models/kanban_*'
      - 'app/controllers/**/kanban_*'
      - 'app/javascript/dashboard/kanban/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'pnpm'
      - name: Run Kanban Tests
        run: |
          bundle exec rspec spec/models/kanban_spec.rb
          bundle exec rspec spec/controllers/kanban_spec.rb
          pnpm test:kanban
      - name: Performance Tests
        run: bundle exec rspec spec/performance/kanban_performance_spec.rb

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Staging
        run: ./scripts/deploy-staging.sh
      - name: Run E2E Tests
        run: pnpm test:e2e:kanban
      - name: Deploy to Production
        run: ./scripts/deploy-production.sh
```

### 2.2 Database Migration Strategy

**Zero-Downtime Migration:**
```ruby
# Migration execution order
class KanbanDeploymentMigrations
  MIGRATION_ORDER = [
    '001_create_kanban_stages',
    '002_add_kanban_indexes',
    '003_add_kanban_position_column',
    '004_migrate_existing_conversations'
  ].freeze

  def self.execute_safe_migrations
    MIGRATION_ORDER.each do |migration|
      Rails.logger.info "Executing migration: #{migration}"
      # Execute with timeout and rollback capability
      ActiveRecord::Base.transaction do
        yield migration
      end
    end
  end
end
```

**Data Migration Script:**
```ruby
# lib/tasks/kanban_migration.rake
namespace :kanban do
  desc "Migrate existing conversations to kanban stages"
  task migrate_conversations: :environment do
    batch_size = 1000
    total_count = Conversation.count
    
    Conversation.find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |conversation|
        # Assign to appropriate kanban stage based on status
        stage = determine_kanban_stage(conversation)
        conversation.update_column(:kanban_stage_id, stage.id)
      end
      
      puts "Migrated #{batch.size} conversations"
    end
  end
end
```

## 3. Performance Monitoring

### 3.1 Application Performance Monitoring

**New Relic Integration:**
```ruby
# config/newrelic.yml - Kanban specific monitoring
custom_attributes:
  kanban_enabled: true
  kanban_version: "1.0.0"

# Custom metrics
class KanbanMetrics
  def self.track_board_load_time(account_id, duration)
    NewRelic::Agent.record_metric('Custom/Kanban/BoardLoadTime', duration)
    NewRelic::Agent.add_custom_attributes(account_id: account_id)
  end

  def self.track_drag_drop_operation(account_id, success)
    metric = success ? 'Custom/Kanban/DragDrop/Success' : 'Custom/Kanban/DragDrop/Failure'
    NewRelic::Agent.increment_metric(metric)
  end

  def self.track_real_time_events(event_type, latency)
    NewRelic::Agent.record_metric("Custom/Kanban/RealTime/#{event_type}", latency)
  end
end
```

**Custom Performance Tracking:**
```javascript
// app/javascript/dashboard/kanban/performance.js
export class KanbanPerformanceTracker {
  static trackBoardRender(accountId, startTime) {
    const duration = performance.now() - startTime;
    
    // Send to backend
    this.sendMetric('kanban_board_render', {
      account_id: accountId,
      duration: duration,
      timestamp: Date.now()
    });
    
    // Log performance warning if slow
    if (duration > 2000) {
      console.warn(`Slow kanban board render: ${duration}ms`);
    }
  }

  static trackDragDropPerformance(operation, duration) {
    this.sendMetric('kanban_drag_drop', {
      operation: operation,
      duration: duration,
      timestamp: Date.now()
    });
  }

  static sendMetric(metric, data) {
    fetch('/api/v1/performance_metrics', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ metric, data })
    });
  }
}
```

### 3.2 Database Performance Monitoring

**Query Performance Tracking:**
```ruby
# config/initializers/kanban_monitoring.rb
ActiveSupport::Notifications.subscribe 'sql.active_record' do |name, started, finished, unique_id, data|
  sql = data[:sql]
  
  # Monitor kanban-specific queries
  if sql.include?('kanban_stages') || sql.include?('conversations') && sql.include?('kanban')
    duration = finished - started
    
    if duration > 0.1 # Log slow queries
      Rails.logger.warn "Slow Kanban Query: #{sql} (#{duration}s)"
      
      # Send to monitoring service
      KanbanMetrics.track_slow_query(sql, duration)
    end
  end
end
```

## 4. Error Tracking & Logging

### 4.1 Error Monitoring

**Sentry Integration:**
```ruby
# config/initializers/sentry.rb
Sentry.configure do |config|
  config.before_send = lambda do |event, hint|
    # Add kanban context to all errors
    if hint[:exception].is_a?(KanbanError)
      event.tags[:component] = 'kanban'
      event.extra[:kanban_context] = hint[:exception].kanban_context
    end
    event
  end
end

# Custom error classes
class KanbanError < StandardError
  attr_reader :kanban_context

  def initialize(message, context = {})
    super(message)
    @kanban_context = context
  end
end

class KanbanStageError < KanbanError; end
class KanbanDragDropError < KanbanError; end
class KanbanRealTimeError < KanbanError; end
```

**Frontend Error Tracking:**
```javascript
// app/javascript/dashboard/kanban/errorTracking.js
export class KanbanErrorTracker {
  static captureError(error, context = {}) {
    const kanbanContext = {
      component: 'kanban',
      boardId: context.boardId,
      stageId: context.stageId,
      conversationId: context.conversationId,
      operation: context.operation,
      timestamp: Date.now()
    };

    // Send to Sentry
    Sentry.withScope(scope => {
      scope.setTag('component', 'kanban');
      scope.setContext('kanban', kanbanContext);
      Sentry.captureException(error);
    });

    // Log locally for debugging
    console.error('Kanban Error:', error, kanbanContext);
  }

  static capturePerformanceIssue(metric, value, threshold) {
    if (value > threshold) {
      this.captureError(new Error(`Performance issue: ${metric}`), {
        metric,
        value,
        threshold,
        operation: 'performance_monitoring'
      });
    }
  }
}
```

### 4.2 Structured Logging

**Backend Logging:**
```ruby
# app/services/kanban_logger.rb
class KanbanLogger
  def self.log_board_action(action, account_id, user_id, context = {})
    Rails.logger.info({
      component: 'kanban',
      action: action,
      account_id: account_id,
      user_id: user_id,
      timestamp: Time.current.iso8601,
      context: context
    }.to_json)
  end

  def self.log_performance_metric(metric, value, context = {})
    Rails.logger.info({
      component: 'kanban',
      type: 'performance',
      metric: metric,
      value: value,
      timestamp: Time.current.iso8601,
      context: context
    }.to_json)
  end

  def self.log_error(error, context = {})
    Rails.logger.error({
      component: 'kanban',
      type: 'error',
      error: error.message,
      backtrace: error.backtrace.first(10),
      timestamp: Time.current.iso8601,
      context: context
    }.to_json)
  end
end
```

## 5. Health Checks & Alerts

### 5.1 Application Health Checks

**Kanban Health Check Endpoint:**
```ruby
# app/controllers/api/v1/health/kanban_controller.rb
class Api::V1::Health::KanbanController < ApplicationController
  def show
    health_status = {
      kanban_enabled: Flipper.enabled?(KanbanFeatureFlags::KANBAN_ENABLED),
      database_connectivity: check_database_connectivity,
      redis_connectivity: check_redis_connectivity,
      websocket_health: check_websocket_health,
      performance_metrics: check_performance_metrics,
      error_rate: check_error_rate,
      timestamp: Time.current.iso8601
    }

    status_code = health_status.values.all? ? 200 : 503
    render json: health_status, status: status_code
  end

  private

  def check_database_connectivity
    KanbanStage.count
    true
  rescue => e
    Rails.logger.error "Kanban DB health check failed: #{e.message}"
    false
  end

  def check_redis_connectivity
    Redis.current.ping == 'PONG'
  rescue => e
    Rails.logger.error "Kanban Redis health check failed: #{e.message}"
    false
  end

  def check_performance_metrics
    # Check average response time is under threshold
    avg_response_time = KanbanMetrics.average_response_time
    avg_response_time < 2.0 # 2 seconds threshold
  end
end
```

### 5.2 Monitoring Alerts

**Alert Configuration:**
```yaml
# monitoring/alerts/kanban-alerts.yml
alerts:
  - name: kanban_high_error_rate
    condition: error_rate > 5%
    duration: 5m
    channels: [slack-dev, pagerduty]
    
  - name: kanban_slow_response_time
    condition: avg_response_time > 3s
    duration: 10m
    channels: [slack-dev]
    
  - name: kanban_websocket_failures
    condition: websocket_error_rate > 10%
    duration: 2m
    channels: [slack-dev, pagerduty]
    
  - name: kanban_database_issues
    condition: db_connection_failures > 0
    duration: 1m
    channels: [slack-dev, pagerduty]
```

## 6. Rollback Strategy

### 6.1 Feature Flag Rollback

**Immediate Rollback:**
```ruby
# lib/tasks/kanban_rollback.rake
namespace :kanban do
  desc "Emergency rollback of kanban features"
  task emergency_rollback: :environment do
    puts "Initiating emergency kanban rollback..."
    
    # Disable all kanban features
    Flipper.disable(KanbanFeatureFlags::KANBAN_ENABLED)
    Flipper.disable(KanbanFeatureFlags::KANBAN_DRAG_DROP)
    Flipper.disable(KanbanFeatureFlags::KANBAN_REAL_TIME)
    Flipper.disable(KanbanFeatureFlags::KANBAN_ANALYTICS)
    
    # Clear kanban caches
    Rails.cache.delete_matched("kanban:*")
    
    # Restart background jobs
    Sidekiq::Queue.new('kanban').clear
    
    puts "Kanban features disabled. System reverted to conversation list view."
  end
end
```

### 6.2 Database Rollback

**Safe Migration Rollback:**
```ruby
# Database rollback strategy
class KanbanRollbackStrategy
  def self.rollback_to_conversation_list
    ActiveRecord::Base.transaction do
      # Preserve conversation data but remove kanban associations
      Conversation.where.not(kanban_stage_id: nil).update_all(kanban_stage_id: nil)
      
      # Keep kanban tables for data recovery but mark as inactive
      KanbanStage.update_all(active: false)
      
      Rails.logger.info "Kanban rollback completed. Conversations preserved."
    end
  rescue => e
    Rails.logger.error "Kanban rollback failed: #{e.message}"
    raise
  end
end
```

## 7. Implementation Timeline

### 7.1 Deployment Schedule

**Week 1: Pre-deployment Setup**
- [ ] Configure feature flags infrastructure
- [ ] Set up monitoring and alerting
- [ ] Deploy health check endpoints
- [ ] Configure CI/CD pipeline
- [ ] Prepare rollback procedures

**Week 2: Internal Testing**
- [ ] Enable kanban for internal accounts only
- [ ] Validate all functionality works correctly
- [ ] Monitor performance metrics
- [ ] Fix any critical issues discovered

**Week 3: Beta Testing**
- [ ] Enable for 5% of production accounts
- [ ] Monitor error rates and performance
- [ ] Collect user feedback
- [ ] Optimize based on real usage patterns

**Week 4-6: Gradual Rollout**
- [ ] Week 4: 25% rollout with close monitoring
- [ ] Week 5: 50% rollout if metrics are stable
- [ ] Week 6: 75% rollout with final validations

**Week 7: Full Rollout**
- [ ] Enable for all accounts
- [ ] Monitor for 48 hours
- [ ] Remove feature flags if stable
- [ ] Complete deployment documentation

### 7.2 Success Metrics

**Performance Targets:**
- Board load time: < 2 seconds (95th percentile)
- Drag & drop response: < 500ms
- Real-time event latency: < 200ms
- Error rate: < 1%
- WebSocket connection success: > 99%

**Business Metrics:**
- User adoption rate: > 70% within 30 days
- Conversation resolution time improvement: > 15%
- User satisfaction score: > 4.5/5
- Support ticket reduction: > 20%

## 8. Post-Deployment Tasks

### 8.1 Monitoring Setup

- [ ] Configure dashboards for all metrics
- [ ] Set up automated reporting
- [ ] Establish regular performance reviews
- [ ] Create incident response procedures

### 8.2 Documentation Updates

- [ ] Update user documentation
- [ ] Create admin configuration guide
- [ ] Document troubleshooting procedures
- [ ] Update API documentation

### 8.3 Team Training

- [ ] Train support team on new features
- [ ] Update onboarding documentation
- [ ] Create troubleshooting guides
- [ ] Establish feedback collection process

## Integration Points

**Related Shards:**
- **Shard 01**: Database schema must be deployed first
- **Shard 02-03**: Core functionality must be tested before deployment
- **Shard 04**: Real-time features require careful monitoring
- **Shard 05**: Security measures must be validated in production
- **Shard 06**: Performance optimizations should be monitored
- **Shard 07**: All tests must pass before any deployment phase

**External Dependencies:**
- Feature flag service (Flipper)
- Monitoring services (New Relic, Sentry)
- CI/CD pipeline (GitHub Actions)
- Infrastructure (Redis, PostgreSQL)

---

This deployment and monitoring guide ensures a safe, gradual rollout of the Kanban system with comprehensive monitoring, error tracking, and rollback capabilities. Follow this guide in conjunction with the implementation guides from shards 01-07 to ensure a successful production deployment.