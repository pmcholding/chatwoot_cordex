# Kanban System - Backend Core Implementation

## Overview

This guide provides the complete backend implementation for the Chatwoot Kanban System. This covers models, controllers, services, and policies required for the core Kanban functionality.

**Implementation Priority:** 🔴 Critical (Week 1-2)  
**Dependencies:** [Shard 1 - Database Migration](./01-database-migration.md)  
**Target Audience:** Backend Development Team

---

## Model Layer Implementation

### KanbanStage Model

```ruby
# app/models/kanban_stage.rb
class KanbanStage < ApplicationRecord
  belongs_to :account
  has_many :conversations, dependent: :nullify
  
  validates :name, presence: true, length: { maximum: 255 }
  validates :name, uniqueness: { scope: :account_id }
  validates :color, presence: true, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }
  validates :position, presence: true, uniqueness: { scope: :account_id }
  validates :position, numericality: { greater_than: 0, less_than_or_equal_to: 20 }
  
  scope :ordered, -> { order(:position) }
  scope :for_account, ->(account) { where(account: account) }
  
  before_validation :set_next_position, if: :new_record?
  after_create :broadcast_stage_created
  after_update :broadcast_stage_updated
  after_destroy :broadcast_stage_destroyed
  
  def conversations_count
    conversations.count
  end
  
  def move_to_position!(new_position)
    transaction do
      if new_position < position
        # Moving up: shift others down
        account.kanban_stages
               .where(position: new_position...position)
               .update_all('position = position + 1')
      else
        # Moving down: shift others up
        account.kanban_stages
               .where(position: (position + 1)..new_position)
               .update_all('position = position - 1')
      end
      
      update!(position: new_position)
    end
  end
  
  private
  
  def set_next_position
    self.position ||= account.kanban_stages.maximum(:position).to_i + 1
  end
  
  def broadcast_stage_created
    ActionCable.server.broadcast(
      "account_#{account_id}_kanban",
      { type: 'stage_created', stage: KanbanStageSerializer.new(self).serializable_hash }
    )
  end
  
  def broadcast_stage_updated
    ActionCable.server.broadcast(
      "account_#{account_id}_kanban",
      { type: 'stage_updated', stage: KanbanStageSerializer.new(self).serializable_hash }
    )
  end
  
  def broadcast_stage_destroyed
    ActionCable.server.broadcast(
      "account_#{account_id}_kanban",
      { type: 'stage_destroyed', stage_id: id }
    )
  end
end
```

### Extended Conversation Model

```ruby
# app/models/conversation.rb (additions)
class Conversation < ApplicationRecord
  # ... existing code ...
  
  belongs_to :kanban_stage, optional: true
  
  scope :in_kanban_stage, ->(stage) { where(kanban_stage: stage) }
  scope :without_kanban_stage, -> { where(kanban_stage: nil) }
  scope :kanban_ordered, -> { order(:updated_at, :created_at) }
  
  after_update :broadcast_kanban_stage_change, if: :saved_change_to_kanban_stage_id?
  
  def move_to_stage!(stage)
    transaction do
      old_stage = kanban_stage
      update!(kanban_stage: stage)
      
      # Log the stage change
      create_activity(
        key: 'kanban_stage_changed',
        parameters: {
          old_stage: old_stage&.name,
          new_stage: stage&.name,
          changed_by: Current.user&.name
        }
      )
    end
  end
  
  private
  
  def broadcast_kanban_stage_change
    ActionCable.server.broadcast(
      "account_#{account_id}_kanban",
      {
        type: 'conversation_stage_changed',
        conversation_id: id,
        old_stage_id: kanban_stage_id_before_last_save,
        new_stage_id: kanban_stage_id,
        conversation: ConversationSerializer.new(self).serializable_hash
      }
    )
  end
end
```

---

## Controller Layer

### KanbanStages Controller

```ruby
# app/controllers/api/v1/kanban_stages_controller.rb
class Api::V1::KanbanStagesController < Api::V1::BaseController
  before_action :check_authorization
  before_action :set_kanban_stage, only: [:show, :update, :destroy]
  
  def index
    @kanban_stages = Current.account.kanban_stages.ordered.includes(:conversations)
    render json: KanbanStageSerializer.new(@kanban_stages, include_conversations_count: true)
  end
  
  def show
    render json: KanbanStageSerializer.new(@kanban_stage)
  end
  
  def create
    @kanban_stage = Current.account.kanban_stages.build(kanban_stage_params)
    
    if @kanban_stage.save
      render json: KanbanStageSerializer.new(@kanban_stage), status: :created
    else
      render json: { errors: @kanban_stage.errors }, status: :unprocessable_entity
    end
  end
  
  def update
    if @kanban_stage.update(kanban_stage_params)
      render json: KanbanStageSerializer.new(@kanban_stage)
    else
      render json: { errors: @kanban_stage.errors }, status: :unprocessable_entity
    end
  end
  
  def destroy
    conversations_count = @kanban_stage.conversations_count
    
    if conversations_count > 0
      render json: { 
        error: 'Cannot delete stage with conversations',
        conversations_count: conversations_count 
      }, status: :unprocessable_entity
    else
      @kanban_stage.destroy
      head :no_content
    end
  end
  
  def reorder
    position_updates = params[:positions] # Array of {id: 1, position: 2}
    
    KanbanStage.transaction do
      position_updates.each do |update|
        stage = Current.account.kanban_stages.find(update[:id])
        stage.move_to_position!(update[:position])
      end
    end
    
    render json: { success: true }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Stage not found' }, status: :not_found
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  private
  
  def set_kanban_stage
    @kanban_stage = Current.account.kanban_stages.find(params[:id])
  end
  
  def kanban_stage_params
    params.require(:kanban_stage).permit(:name, :color, :position)
  end
  
  def check_authorization
    authorize(KanbanStage)
  end
end
```

### Extended Conversations Controller

```ruby
# app/controllers/api/v1/conversations_controller.rb (additions)
class Api::V1::ConversationsController < Api::V1::BaseController
  # ... existing actions ...
  
  def update_kanban_stage
    @conversation = Current.account.conversations.find(params[:id])
    authorize @conversation, :update?
    
    if params[:kanban_stage_id].present?
      stage = Current.account.kanban_stages.find(params[:kanban_stage_id])
      @conversation.move_to_stage!(stage)
    else
      @conversation.move_to_stage!(nil)
    end
    
    render json: ConversationSerializer.new(@conversation)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Stage not found' }, status: :not_found
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  def kanban_board
    stages = Current.account.kanban_stages.ordered.includes(:conversations)
    conversations_by_stage = {}
    
    stages.each do |stage|
      conversations_by_stage[stage.id] = paginated_conversations_for_stage(stage)
    end
    
    # Include conversations without stage
    conversations_by_stage['unassigned'] = paginated_conversations_for_stage(nil)
    
    render json: {
      stages: KanbanStageSerializer.new(stages),
      conversations_by_stage: conversations_by_stage,
      meta: pagination_meta
    }
  end
  
  private
  
  def paginated_conversations_for_stage(stage)
    conversations = if stage
                     stage.conversations
                   else
                     Current.account.conversations.without_kanban_stage
                   end
    
    # Apply existing filters (inbox, assignee, status, etc.)
    conversations = apply_filters(conversations)
    
    # Paginate
    conversations = conversations.kanban_ordered
                                .limit(params[:limit] || 30)
                                .offset(params[:offset] || 0)
    
    ConversationSerializer.new(conversations, include_associations: true)
  end
end
```

---

## Service Layer

### KanbanStage Service

```ruby
# app/services/kanban_stage_service.rb
class KanbanStageService
  include Service::Base
  
  def self.create_default_stages_for_account(account)
    stages_data = [
      { name: 'New', color: '#3b82f6', position: 1 },
      { name: 'In Progress', color: '#f59e0b', position: 2 },
      { name: 'Review', color: '#10b981', position: 3 },
      { name: 'Resolved', color: '#6366f1', position: 4 }
    ]
    
    stages_data.map do |stage_data|
      account.kanban_stages.create!(stage_data)
    end
  end
  
  def self.bulk_move_conversations(conversation_ids, target_stage, current_user)
    conversations = Conversation.where(id: conversation_ids)
    
    Conversation.transaction do
      conversations.each do |conversation|
        next unless Pundit.policy(current_user, conversation).update?
        
        conversation.move_to_stage!(target_stage)
      end
    end
    
    conversations.reload
  end
  
  def self.migrate_conversations_from_deleted_stage(stage)
    default_stage = stage.account.kanban_stages.ordered.first
    
    stage.conversations.update_all(kanban_stage_id: default_stage&.id)
  end
end
```

---

## Policy Layer

### KanbanStage Policy

```ruby
# app/policies/kanban_stage_policy.rb
class KanbanStagePolicy < ApplicationPolicy
  def index?
    @user.administrator? || @user.agent?
  end
  
  def show?
    index?
  end
  
  def create?
    @user.administrator?
  end
  
  def update?
    @user.administrator?
  end
  
  def destroy?
    @user.administrator?
  end
  
  def reorder?
    @user.administrator?
  end
  
  class Scope < Scope
    def resolve
      if user.administrator?
        scope.all
      else
        scope.none
      end
    end
  end
end
```

---

## Serializers

### KanbanStage Serializer

```ruby
# app/serializers/kanban_stage_serializer.rb
class KanbanStageSerializer < ApplicationSerializer
  attributes :id, :name, :color, :position, :created_at, :updated_at
  
  attribute :conversations_count, if: proc { |record, params|
    params[:include_conversations_count]
  }
  
  def conversations_count
    object.conversations_count
  end
end
```

### Extended Conversation Serializer

```ruby
# app/serializers/conversation_serializer.rb (additions)
class ConversationSerializer < ApplicationSerializer
  # ... existing attributes ...
  
  attribute :kanban_stage_id
  
  has_one :kanban_stage, serializer: KanbanStageSerializer, if: proc { |record|
    record.kanban_stage.present?
  }
end
```

---

## Routes Configuration

```ruby
# config/routes.rb (additions)
Rails.application.routes.draw do
  # ... existing routes ...
  
  namespace :api do
    namespace :v1 do
      scope :accounts, path: 'accounts/:account_id' do
        # Kanban Stages
        resources :kanban_stages do
          collection do
            patch :reorder
          end
        end
        
        # Conversations Kanban
        resources :conversations do
          member do
            patch :kanban_stage, action: :update_kanban_stage
          end
          
          collection do
            get :kanban_board
          end
        end
      end
    end
  end
end
```

---

## Error Handling

### Custom Exceptions

```ruby
# lib/custom_exceptions/kanban_exceptions.rb
module CustomExceptions
  class KanbanStageNotFound < CustomExceptions::Base
    def message
      'Kanban stage not found'
    end
  end
  
  class KanbanStageHasConversations < CustomExceptions::Base
    def message
      'Cannot delete stage with active conversations'
    end
  end
  
  class InvalidStagePosition < CustomExceptions::Base
    def message
      'Invalid stage position'
    end
  end
end
```

### Error Handling in Controllers

```ruby
# app/controllers/concerns/kanban_error_handler.rb
module KanbanErrorHandler
  extend ActiveSupport::Concern
  
  included do
    rescue_from CustomExceptions::KanbanStageNotFound, with: :kanban_stage_not_found
    rescue_from CustomExceptions::KanbanStageHasConversations, with: :kanban_stage_has_conversations
    rescue_from CustomExceptions::InvalidStagePosition, with: :invalid_stage_position
  end
  
  private
  
  def kanban_stage_not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end
  
  def kanban_stage_has_conversations(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
  
  def invalid_stage_position(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
```

---

## Testing Helpers

### Model Factories

```ruby
# spec/factories/kanban_stages.rb
FactoryBot.define do
  factory :kanban_stage do
    account
    sequence(:name) { |n| "Stage #{n}" }
    color { '#3b82f6' }
    sequence(:position) { |n| n }
  end
end
```

### Test Helpers

```ruby
# spec/support/kanban_helpers.rb
module KanbanHelpers
  def create_kanban_stages_for_account(account, count = 4)
    count.times do |i|
      create(:kanban_stage, account: account, position: i + 1)
    end
  end
  
  def move_conversation_to_stage(conversation, stage)
    conversation.move_to_stage!(stage)
    conversation.reload
  end
end
```

---

## Implementation Checklist

### Models
- [ ] Create KanbanStage model with validations
- [ ] Add kanban_stage association to Conversation model
- [ ] Implement position management methods
- [ ] Add broadcasting callbacks
- [ ] Test model validations and associations

### Controllers
- [ ] Implement KanbanStagesController with CRUD operations
- [ ] Add kanban_stage update action to ConversationsController
- [ ] Implement kanban_board endpoint
- [ ] Add proper authorization checks
- [ ] Test all controller actions

### Services
- [ ] Create KanbanStageService for business logic
- [ ] Implement default stage creation
- [ ] Add bulk operations support
- [ ] Test service methods

### Policies
- [ ] Create KanbanStagePolicy with role-based permissions
- [ ] Test policy methods for different user types
- [ ] Integrate with existing authorization system

### Routes & Serializers
- [ ] Add routes for kanban endpoints
- [ ] Create KanbanStageSerializer
- [ ] Extend ConversationSerializer
- [ ] Test API response formats

---

## Integration Points

**Database Dependencies:**
- ✅ Requires completed [Database Migration](./01-database-migration.md)

**Next Steps:**
- 🔄 **Frontend Integration**: API endpoints ready for [Frontend Implementation](./03-frontend-components.md)
- 🔄 **Security Integration**: Models ready for [Security Implementation](./05-security-implementation.md)
- 🔄 **Real-time Integration**: Broadcasting ready for [Real-time Implementation](./04-realtime-integration.md)

**Testing Dependencies:**
- 🔄 Models and controllers ready for [Testing Implementation](./07-testing-guide.md)

**Related Documents:**
- [Database Migration Guide](./01-database-migration.md)
- [Frontend Components Guide](./03-frontend-components.md)
- [Security Implementation Guide](./05-security-implementation.md)