# Kanban System - Security & Authentication

## Overview

This guide provides comprehensive security implementation for the Chatwoot Kanban System. This covers policy-based access control, input validation, rate limiting, and data privacy compliance.

**Implementation Priority:** 🔴 Critical (Week 2-3)  
**Dependencies:** [Shard 2 - Backend Core](./02-backend-core.md)  
**Target Audience:** Security Team, Backend Team

---

## Policy-Based Access Control

### KanbanStage Policy

```ruby
# app/policies/kanban_stage_policy.rb
class KanbanStagePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      # Users can only see stages from their account
      scope.where(account: user.account)
    end
  end

  def index?
    user.agent? || user.administrator?
  end

  def show?
    index? && record.account == user.account
  end

  def create?
    user.administrator? && can_manage_account?
  end

  def update?
    user.administrator? && record.account == user.account
  end

  def destroy?
    update? && !record.has_conversations?
  end

  def reorder?
    update?
  end

  private

  def can_manage_account?
    user.account == Account.find(context[:account_id])
  end
end
```

### Enhanced Conversation Policy

```ruby
# app/policies/conversation_policy.rb (Kanban additions)
class ConversationPolicy < ApplicationPolicy
  # ... existing methods ...

  def update_kanban_stage?
    # Allow agents to move conversations in their assigned inboxes
    return false unless user.agent? || user.administrator?
    
    # Check if user has access to the conversation's inbox
    return false unless user.assigned_inboxes.include?(record.inbox)
    
    # Check account ownership
    record.account == user.account
  end

  def view_kanban_board?
    user.agent? || user.administrator?
  end

  class Scope < Scope
    def resolve_for_kanban
      # Return conversations user can view in Kanban
      if user.administrator?
        scope.where(account: user.account)
      else
        scope.joins(:inbox)
             .where(account: user.account, inbox: user.assigned_inboxes)
      end
    end
  end
end
```

### ActionCable Authorization

```ruby
# app/channels/kanban_channel.rb (security enhancements)
class KanbanChannel < ApplicationCable::Channel
  def subscribed
    ensure_confirmation_sent
    
    # Verify account access
    account = Account.find(params[:account_id])
    authorize_account_access(account)
    
    # Additional validation for kanban feature access
    unless FeatureFlags.enabled?('kanban_enabled', account)
      reject_unauthorized_connection
      return
    end
    
    stream_from "account_#{account.id}_kanban"
    log_channel_subscription(account)
  end

  def unsubscribed
    log_channel_unsubscription
  end

  private

  def authorize_account_access(account)
    policy = Pundit.policy(current_user, account)
    raise Pundit::NotAuthorizedError unless policy.show?
    
    # Verify user belongs to account
    unless current_user.account == account
      reject_unauthorized_connection
      raise Pundit::NotAuthorizedError, 'User does not belong to account'
    end
  end

  def log_channel_subscription(account)
    Rails.logger.info({
      event: 'kanban_channel_subscribed',
      user_id: current_user.id,
      account_id: account.id,
      ip_address: connection.request.remote_ip
    }.to_json)
  end

  def log_channel_unsubscription
    Rails.logger.info({
      event: 'kanban_channel_unsubscribed',
      user_id: current_user&.id,
      ip_address: connection.request.remote_ip
    }.to_json)
  end
end
```

---

## Input Validation & Sanitization

### Kanban Security Concern

```ruby
# app/controllers/concerns/kanban_security.rb
module KanbanSecurity
  extend ActiveSupport::Concern

  private

  def sanitize_kanban_stage_params
    params.require(:kanban_stage).permit(:name, :color, :position).tap do |stage_params|
      # Sanitize name
      stage_params[:name] = ActionController::Base.helpers.sanitize(
        stage_params[:name],
        tags: [],
        attributes: []
      ).strip.truncate(255)

      # Validate color format
      stage_params[:color] = validate_color_format(stage_params[:color])

      # Validate position
      stage_params[:position] = validate_position(stage_params[:position])
    end
  end

  def validate_color_format(color)
    return '#6366f1' unless color.is_a?(String)
    
    # Remove any non-hex characters and ensure proper format
    cleaned_color = color.gsub(/[^#0-9A-Fa-f]/, '')
    cleaned_color = "##{cleaned_color}" unless cleaned_color.start_with?('#')
    
    # Validate hex format
    if cleaned_color.match?(/\A#[0-9A-Fa-f]{6}\z/)
      cleaned_color
    else
      '#6366f1' # Default color
    end
  end

  def validate_position(position)
    pos = position.to_i
    pos.clamp(1, 20) # Limit to reasonable range
  end

  def validate_conversation_ownership(conversation)
    unless conversation.account == Current.account
      raise Pundit::NotAuthorizedError, 'Conversation does not belong to current account'
    end
  end

  def validate_stage_ownership(stage)
    unless stage.account == Current.account
      raise Pundit::NotAuthorizedError, 'Stage does not belong to current account'
    end
  end

  def sanitize_filter_params
    return {} unless params[:filters].present?
    
    permitted_filters = params.require(:filters).permit(
      :search,
      :created_after,
      :created_before,
      inbox_ids: [],
      assignee_ids: [],
      label_ids: [],
      statuses: []
    )
    
    # Sanitize search query
    if permitted_filters[:search].present?
      permitted_filters[:search] = sanitize_search_query(permitted_filters[:search])
    end
    
    # Validate date formats
    %i[created_after created_before].each do |date_param|
      if permitted_filters[date_param].present?
        permitted_filters[date_param] = validate_date_format(permitted_filters[date_param])
      end
    end
    
    # Validate array parameters
    %i[inbox_ids assignee_ids label_ids].each do |array_param|
      if permitted_filters[array_param].present?
        permitted_filters[array_param] = validate_id_array(permitted_filters[array_param])
      end
    end
    
    permitted_filters
  end

  def sanitize_search_query(query)
    # Remove potential SQL injection patterns
    cleaned_query = query.to_s.strip
    cleaned_query = cleaned_query.gsub(/[;'"]/, '')
    cleaned_query.truncate(255)
  end

  def validate_date_format(date_string)
    Date.parse(date_string)
    date_string
  rescue Date::Error
    nil
  end

  def validate_id_array(ids)
    return [] unless ids.is_a?(Array)
    
    ids.map(&:to_i).select(&:positive?).uniq.first(100) # Limit to 100 IDs
  end
end
```

### Enhanced Model Validations

```ruby
# app/models/kanban_stage.rb (security additions)
class KanbanStage < ApplicationRecord
  # ... existing code ...
  
  # Additional security validations
  validates :name, format: { 
    without: /[<>"]/, 
    message: 'cannot contain HTML characters' 
  }
  
  validates :color, format: { 
    with: /\A#[0-9A-Fa-f]{6}\z/,
    message: 'must be a valid hex color'
  }
  
  validate :max_stages_per_account
  validate :name_not_reserved
  
  private
  
  def max_stages_per_account
    return unless account
    
    existing_count = account.kanban_stages.where.not(id: id).count
    if existing_count >= 20
      errors.add(:base, 'Maximum of 20 stages allowed per account')
    end
  end
  
  def name_not_reserved
    reserved_names = %w[admin system root null undefined]
    if reserved_names.include?(name&.downcase)
      errors.add(:name, 'cannot use reserved name')
    end
  end
end
```

---

## Rate Limiting

### Rack Attack Configuration

```ruby
# config/initializers/rack_attack.rb (Kanban additions)

# Kanban-specific rate limiting
Rack::Attack.throttle('kanban_stage_operations/account/hour', limit: 100, period: 1.hour) do |req|
  if req.path.match?(%r{/api/v1/accounts/\d+/kanban_stages}) && req.post?
    account_id = req.path.match(%r{/accounts/(\d+)/})[1]
    "kanban_stage_operations:#{account_id}"
  end
end

Rack::Attack.throttle('kanban_stage_updates/user/minute', limit: 30, period: 1.minute) do |req|
  if req.path.match?(%r{/kanban_stage}) && (req.patch? || req.put?)
    req.ip
  end
end

Rack::Attack.throttle('conversation_stage_updates/user/minute', limit: 60, period: 1.minute) do |req|
  if req.path.match?(%r{/conversations/\d+/kanban_stage}) && req.patch?
    req.ip
  end
end

Rack::Attack.throttle('kanban_board_requests/user/minute', limit: 20, period: 1.minute) do |req|
  if req.path.match?(%r{/conversations/kanban_board}) && req.get?
    req.ip
  end
end

# WebSocket connection rate limiting
Rack::Attack.throttle('kanban_websocket/ip/minute', limit: 10, period: 1.minute) do |req|
  if req.path == '/cable' && req.env['HTTP_UPGRADE'] == 'websocket'
    req.ip
  end
end
```

### Controller-level Rate Limiting

```ruby
# app/controllers/concerns/kanban_rate_limiting.rb
module KanbanRateLimiting
  extend ActiveSupport::Concern
  
  included do
    before_action :check_kanban_rate_limits
  end
  
  private
  
  def check_kanban_rate_limits
    case action_name
    when 'create', 'update', 'destroy'
      check_modification_rate_limit
    when 'reorder'
      check_reorder_rate_limit
    when 'kanban_board'
      check_board_access_rate_limit
    end
  end
  
  def check_modification_rate_limit
    key = "kanban_modifications:#{current_user.id}"
    
    if rate_limit_exceeded?(key, limit: 10, period: 1.minute)
      render json: { 
        error: 'Rate limit exceeded. Please wait before making more changes.' 
      }, status: :too_many_requests
    end
  end
  
  def check_reorder_rate_limit
    key = "kanban_reorder:#{current_user.id}"
    
    if rate_limit_exceeded?(key, limit: 5, period: 1.minute)
      render json: { 
        error: 'Reorder rate limit exceeded. Please wait before reordering again.' 
      }, status: :too_many_requests
    end
  end
  
  def check_board_access_rate_limit
    key = "kanban_board_access:#{current_user.id}"
    
    if rate_limit_exceeded?(key, limit: 30, period: 1.minute)
      render json: { 
        error: 'Board access rate limit exceeded.' 
      }, status: :too_many_requests
    end
  end
  
  def rate_limit_exceeded?(key, limit:, period:)
    Redis.current.incr(key).tap do |count|
      Redis.current.expire(key, period) if count == 1
      return count > limit
    end
  rescue Redis::BaseError
    false # Fail open if Redis is unavailable
  end
end
```

---

## Data Privacy & Compliance

### GDPR Compliance

```ruby
# app/models/kanban_stage.rb (GDPR additions)
class KanbanStage < ApplicationRecord
  # ... existing code ...
  
  # GDPR compliance methods
  def self.anonymize_for_account(account)
    account.kanban_stages.update_all(
      name: 'Anonymized Stage',
      updated_at: Time.current
    )
  end

  def anonymize!
    update!(
      name: "Stage #{id}",
      updated_at: Time.current
    )
  end
  
  def personal_data_fields
    %w[name] # Only name might contain personal data
  end
  
  def export_personal_data
    {
      id: id,
      name: name,
      created_at: created_at,
      updated_at: updated_at
    }
  end
end
```

### Audit Logging

```ruby
# app/models/concerns/kanban_auditable.rb
module KanbanAuditable
  extend ActiveSupport::Concern

  included do
    has_many :audit_logs, as: :auditable, dependent: :destroy
    
    after_create :log_creation
    after_update :log_update
    after_destroy :log_destruction
  end

  private

  def log_creation
    create_audit_log('created', changes_for_audit)
  end

  def log_update
    return unless saved_changes.any?
    create_audit_log('updated', changes_for_audit)
  end

  def log_destruction
    create_audit_log('destroyed', attributes_for_audit)
  end

  def create_audit_log(action, data)
    audit_logs.create!(
      action: action,
      user: Current.user,
      account: account,
      changes: data,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent,
      timestamp: Time.current
    )
  end

  def changes_for_audit
    saved_changes.except('updated_at', 'created_at')
  end

  def attributes_for_audit
    attributes.except('created_at', 'updated_at')
  end
end
```

### Data Encryption

```ruby
# app/models/concerns/kanban_encryption.rb
module KanbanEncryption
  extend ActiveSupport::Concern
  
  included do
    # Encrypt sensitive fields if needed
    encrypts :name, deterministic: true, downcase: true if respond_to?(:encrypts)
  end
  
  def encrypt_sensitive_data
    # Custom encryption for additional fields if needed
    return unless Rails.application.config.encryption_enabled
    
    encrypted_fields.each do |field|
      value = send(field)
      next unless value.present?
      
      send("#{field}=", encrypt_value(value))
    end
  end
  
  private
  
  def encrypted_fields
    [] # Override in including models
  end
  
  def encrypt_value(value)
    Rails.application.message_encryptor.encrypt_and_sign(value)
  end
  
  def decrypt_value(encrypted_value)
    Rails.application.message_encryptor.decrypt_and_verify(encrypted_value)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    encrypted_value # Return original if decryption fails
  end
end
```

---

## Security Headers & CSRF Protection

### Enhanced Controller Security

```ruby
# app/controllers/api/v1/kanban_stages_controller.rb (security additions)
class Api::V1::KanbanStagesController < Api::V1::BaseController
  include KanbanSecurity
  include KanbanRateLimiting
  
  protect_from_forgery with: :exception
  before_action :verify_authenticity_token
  before_action :check_authorization
  before_action :validate_account_access
  before_action :set_security_headers
  
  # ... existing actions ...
  
  private
  
  def validate_account_access
    unless Current.account
      render json: { error: 'Account not found' }, status: :unauthorized
      return
    end
    
    unless current_user.account == Current.account
      render json: { error: 'Unauthorized account access' }, status: :forbidden
      return
    end
  end
  
  def set_security_headers
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
  end
  
  def kanban_stage_params
    sanitize_kanban_stage_params
  end
end
```

### API Request Validation

```ruby
# app/controllers/concerns/api_request_validation.rb
module ApiRequestValidation
  extend ActiveSupport::Concern
  
  included do
    before_action :validate_request_format
    before_action :validate_request_size
    before_action :validate_user_agent
  end
  
  private
  
  def validate_request_format
    unless request.format.json?
      render json: { error: 'Invalid request format' }, status: :bad_request
      return
    end
  end
  
  def validate_request_size
    max_size = 1.megabyte
    if request.content_length && request.content_length > max_size
      render json: { error: 'Request too large' }, status: :payload_too_large
      return
    end
  end
  
  def validate_user_agent
    user_agent = request.user_agent
    
    # Block known malicious user agents
    blocked_patterns = [
      /sqlmap/i,
      /nikto/i,
      /nmap/i,
      /masscan/i
    ]
    
    if blocked_patterns.any? { |pattern| user_agent&.match?(pattern) }
      render json: { error: 'Blocked user agent' }, status: :forbidden
      return
    end
  end
end
```

---

## Error Handling & Information Disclosure

### Secure Error Responses

```ruby
# app/controllers/concerns/secure_error_handling.rb
module SecureErrorHandling
  extend ActiveSupport::Concern
  
  included do
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
  end
  
  private
  
  def handle_standard_error(exception)
    log_security_error(exception)
    
    if Rails.env.production?
      render json: { error: 'An error occurred' }, status: :internal_server_error
    else
      render json: { 
        error: exception.message,
        backtrace: exception.backtrace.first(10)
      }, status: :internal_server_error
    end
  end
  
  def handle_not_found(exception)
    log_security_event('resource_not_found', { resource: exception.model })
    render json: { error: 'Resource not found' }, status: :not_found
  end
  
  def handle_unauthorized(exception)
    log_security_event('unauthorized_access', { 
      action: action_name,
      resource: exception.record&.class&.name
    })
    render json: { error: 'Unauthorized' }, status: :forbidden
  end
  
  def handle_parameter_missing(exception)
    log_security_event('parameter_missing', { param: exception.param })
    render json: { error: 'Required parameter missing' }, status: :bad_request
  end
  
  def log_security_error(exception)
    Rails.logger.error({
      event: 'kanban_security_error',
      error_class: exception.class.name,
      error_message: exception.message,
      user_id: current_user&.id,
      account_id: Current.account&.id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      request_path: request.path,
      request_method: request.method
    }.to_json)
  end
  
  def log_security_event(event_type, additional_data = {})
    Rails.logger.warn({
      event: "kanban_security_#{event_type}",
      user_id: current_user&.id,
      account_id: Current.account&.id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      request_path: request.path,
      **additional_data
    }.to_json)
  end
end
```

---

## Implementation Checklist

### Access Control
- [ ] Implement KanbanStage policy with role-based permissions
- [ ] Enhance Conversation policy for Kanban operations
- [ ] Add ActionCable channel authorization
- [ ] Test policy enforcement across all endpoints
- [ ] Validate account isolation

### Input Validation
- [ ] Sanitize all user inputs in controllers
- [ ] Add model-level validation enhancements
- [ ] Implement parameter filtering
- [ ] Test input validation edge cases
- [ ] Verify XSS protection

### Rate Limiting
- [ ] Configure Rack Attack for Kanban endpoints
- [ ] Add controller-level rate limiting
- [ ] Implement WebSocket connection limits
- [ ] Test rate limiting effectiveness
- [ ] Monitor rate limit violations

### Data Protection
- [ ] Implement GDPR compliance methods
- [ ] Add comprehensive audit logging
- [ ] Set up data encryption for sensitive fields
- [ ] Test data anonymization
- [ ] Verify audit trail completeness

### Error Handling
- [ ] Implement secure error responses
- [ ] Add comprehensive logging
- [ ] Remove information disclosure risks
- [ ] Test error handling scenarios
- [ ] Verify security event logging

---

## Integration Points

**Dependencies:**
- ✅ Requires [Backend Core](./02-backend-core.md) models and controllers

**Security Coordination:**
- 🔄 **Frontend Security**: Ensure frontend validates permissions
- 🔄 **Real-time Security**: WebSocket authorization
- 🔄 **Testing Security**: Security tests in [Testing Implementation](./07-testing-guide.md)

**Related Documents:**
- [Backend Core Implementation](./02-backend-core.md)
- [Frontend Components Guide](./03-frontend-components.md)
- [Real-time Integration Guide](./04-realtime-integration.md)
- [Testing Guide](./07-testing-guide.md)