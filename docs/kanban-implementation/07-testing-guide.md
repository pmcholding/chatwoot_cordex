# Kanban System - Testing Strategy & Implementation

## Overview

This guide provides comprehensive testing strategies for the Chatwoot Kanban System. This covers unit tests, integration tests, end-to-end tests, and performance testing across all components.

**Implementation Priority:** 🟡 High (Week 3-6, parallel)  
**Dependencies:** Corresponding implementation shards  
**Target Audience:** QA Team, All Development Teams

---

## Backend Testing Strategy

### Model Tests

#### KanbanStage Model Tests

```ruby
# spec/models/kanban_stage_spec.rb
require 'rails_helper'

RSpec.describe KanbanStage, type: :model do
  let(:account) { create(:account) }
  
  describe 'validations' do
    subject { build(:kanban_stage, account: account) }
    
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:color) }
    it { should validate_presence_of(:position) }
    
    it { should validate_uniqueness_of(:name).scoped_to(:account_id) }
    it { should validate_uniqueness_of(:position).scoped_to(:account_id) }
    
    describe 'color validation' do
      it 'accepts valid hex colors' do
        expect(subject).to allow_value('#ff0000').for(:color)
        expect(subject).to allow_value('#FF0000').for(:color)
        expect(subject).to allow_value('#123abc').for(:color)
      end
      
      it 'rejects invalid color formats' do
        expect(subject).not_to allow_value('red').for(:color)
        expect(subject).not_to allow_value('#xyz123').for(:color)
        expect(subject).not_to allow_value('#ff00').for(:color)
        expect(subject).not_to allow_value('123456').for(:color)
      end
    end
    
    describe 'position validation' do
      it 'accepts valid positions' do
        expect(subject).to allow_value(1).for(:position)
        expect(subject).to allow_value(10).for(:position)
        expect(subject).to allow_value(20).for(:position)
      end
      
      it 'rejects invalid positions' do
        expect(subject).not_to allow_value(0).for(:position)
        expect(subject).not_to allow_value(-1).for(:position)
        expect(subject).not_to allow_value(21).for(:position)
      end
    end
    
    describe 'name validation' do
      it 'rejects names with HTML characters' do
        expect(subject).not_to allow_value('<script>alert("xss")</script>').for(:name)
        expect(subject).not_to allow_value('Stage "test"').for(:name)
        expect(subject).not_to allow_value('Stage <tag>').for(:name)
      end
      
      it 'rejects reserved names' do
        %w[admin system root null undefined].each do |reserved_name|
          expect(subject).not_to allow_value(reserved_name).for(:name)
          expect(subject).not_to allow_value(reserved_name.upcase).for(:name)
        end
      end
    end
    
    describe 'max stages per account' do
      it 'allows up to 20 stages per account' do
        create_list(:kanban_stage, 19, account: account)
        new_stage = build(:kanban_stage, account: account)
        expect(new_stage).to be_valid
      end
      
      it 'prevents more than 20 stages per account' do
        create_list(:kanban_stage, 20, account: account)
        new_stage = build(:kanban_stage, account: account)
        expect(new_stage).not_to be_valid
        expect(new_stage.errors[:base]).to include('Maximum of 20 stages allowed per account')
      end
    end
  end
  
  describe 'associations' do
    it { should belong_to(:account) }
    it { should have_many(:conversations).dependent(:nullify) }
  end
  
  describe 'scopes' do
    let!(:stage1) { create(:kanban_stage, account: account, position: 2) }
    let!(:stage2) { create(:kanban_stage, account: account, position: 1) }
    let!(:stage3) { create(:kanban_stage, account: account, position: 3) }
    
    describe '.ordered' do
      it 'returns stages ordered by position' do
        expect(KanbanStage.ordered).to eq([stage2, stage1, stage3])
      end
    end
    
    describe '.for_account' do
      let(:other_account) { create(:account) }
      let!(:other_stage) { create(:kanban_stage, account: other_account) }
      
      it 'returns only stages for the specified account' do
        expect(KanbanStage.for_account(account)).to include(stage1, stage2, stage3)
        expect(KanbanStage.for_account(account)).not_to include(other_stage)
      end
    end
  end
  
  describe '#move_to_position!' do
    let!(:stages) { create_list(:kanban_stage, 5, account: account) }
    
    context 'when moving up' do
      it 'shifts other stages down' do
        stage = stages[3] # position 4
        original_positions = stages.map(&:position)
        
        stage.move_to_position!(2)
        
        stages.each(&:reload)
        expect(stage.position).to eq(2)
        expect(stages[1].position).to eq(3) # was 2, shifted down
        expect(stages[2].position).to eq(4) # was 3, shifted down
      end
    end
    
    context 'when moving down' do
      it 'shifts other stages up' do
        stage = stages[1] # position 2
        
        stage.move_to_position!(4)
        
        stages.each(&:reload)
        expect(stage.position).to eq(4)
        expect(stages[2].position).to eq(2) # was 3, shifted up
        expect(stages[3].position).to eq(3) # was 4, shifted up
      end
    end
    
    it 'handles edge cases' do
      stage = stages.first
      expect { stage.move_to_position!(stage.position) }.not_to change { stage.position }
    end
    
    it 'maintains position uniqueness' do
      stage = stages[2]
      stage.move_to_position!(1)
      
      stages.each(&:reload)
      positions = stages.map(&:position).sort
      expect(positions).to eq([1, 2, 3, 4, 5])
    end
  end
  
  describe 'callbacks' do
    let(:stage) { build(:kanban_stage, account: account) }
    
    describe 'position setting' do
      it 'sets next position automatically for new records' do
        existing_stage = create(:kanban_stage, account: account, position: 3)
        new_stage = build(:kanban_stage, account: account, position: nil)
        
        new_stage.validate
        expect(new_stage.position).to eq(4)
      end
    end
  end
  
  describe 'broadcasting' do
    let(:stage) { build(:kanban_stage, account: account) }
    
    it 'broadcasts stage creation' do
      expect { stage.save! }
        .to have_broadcasted_to("account_#{account.id}_kanban")
        .with(hash_including(type: 'stage_created'))
    end
    
    it 'broadcasts stage updates' do
      stage.save!
      
      expect { stage.update!(name: 'Updated Name') }
        .to have_broadcasted_to("account_#{account.id}_kanban")
        .with(hash_including(type: 'stage_updated'))
    end
    
    it 'broadcasts stage destruction' do
      stage.save!
      
      expect { stage.destroy! }
        .to have_broadcasted_to("account_#{account.id}_kanban")
        .with(hash_including(type: 'stage_destroyed'))
    end
  end
  
  describe '#conversations_count' do
    let(:stage) { create(:kanban_stage, account: account) }
    
    it 'returns correct conversation count' do
      expect(stage.conversations_count).to eq(0)
      
      create_list(:conversation, 3, account: account, kanban_stage: stage)
      expect(stage.conversations_count).to eq(3)
    end
  end
end
```

#### Enhanced Conversation Model Tests

```ruby
# spec/models/conversation_spec.rb (Kanban additions)
require 'rails_helper'

RSpec.describe Conversation, type: :model do
  let(:account) { create(:account) }
  let(:kanban_stage) { create(:kanban_stage, account: account) }
  
  describe 'kanban associations' do
    it { should belong_to(:kanban_stage).optional }
  end
  
  describe 'kanban scopes' do
    let!(:conversation_with_stage) { create(:conversation, account: account, kanban_stage: kanban_stage) }
    let!(:conversation_without_stage) { create(:conversation, account: account) }
    
    describe '.in_kanban_stage' do
      it 'returns conversations in specified stage' do
        expect(Conversation.in_kanban_stage(kanban_stage)).to include(conversation_with_stage)
        expect(Conversation.in_kanban_stage(kanban_stage)).not_to include(conversation_without_stage)
      end
    end
    
    describe '.without_kanban_stage' do
      it 'returns conversations without kanban stage' do
        expect(Conversation.without_kanban_stage).to include(conversation_without_stage)
        expect(Conversation.without_kanban_stage).not_to include(conversation_with_stage)
      end
    end
    
    describe '.kanban_ordered' do
      it 'orders by updated_at and created_at' do
        old_conversation = create(:conversation, account: account, updated_at: 2.hours.ago)
        new_conversation = create(:conversation, account: account, updated_at: 1.hour.ago)
        
        expect(Conversation.kanban_ordered.first).to eq(old_conversation)
        expect(Conversation.kanban_ordered.last).to eq(new_conversation)
      end
    end
  end
  
  describe '#move_to_stage!' do
    let(:conversation) { create(:conversation, account: account) }
    let(:old_stage) { create(:kanban_stage, account: account, name: 'Old Stage') }
    let(:new_stage) { create(:kanban_stage, account: account, name: 'New Stage') }
    
    before do
      conversation.update!(kanban_stage: old_stage)
    end
    
    it 'moves conversation to new stage' do
      expect { conversation.move_to_stage!(new_stage) }
        .to change { conversation.reload.kanban_stage }.from(old_stage).to(new_stage)
    end
    
    it 'creates activity log' do
      expect { conversation.move_to_stage!(new_stage) }
        .to change { conversation.activities.count }.by(1)
      
      activity = conversation.activities.last
      expect(activity.key).to eq('kanban_stage_changed')
      expect(activity.parameters['old_stage']).to eq('Old Stage')
      expect(activity.parameters['new_stage']).to eq('New Stage')
    end
    
    it 'handles moving to nil stage' do
      expect { conversation.move_to_stage!(nil) }
        .to change { conversation.reload.kanban_stage }.from(old_stage).to(nil)
    end
    
    it 'broadcasts the change' do
      expect { conversation.move_to_stage!(new_stage) }
        .to have_broadcasted_to("account_#{account.id}_kanban")
        .with(hash_including(type: 'conversation_stage_changed'))
    end
  end
end
```

### Controller Tests

#### KanbanStages Controller Tests

```ruby
# spec/controllers/api/v1/kanban_stages_controller_spec.rb
require 'rails_helper'

RSpec.describe Api::V1::KanbanStagesController, type: :controller do
  let(:account) { create(:account) }
  let(:user) { create(:user, :administrator, account: account) }
  let!(:stages) { create_list(:kanban_stage, 3, account: account) }
  
  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_account).and_return(account)
  end
  
  describe 'GET #index' do
    it 'returns all stages for the account' do
      get :index, params: { account_id: account.id }
      
      expect(response).to have_http_status(:ok)
      expect(json_response.size).to eq(3)
      expect(json_response.map { |s| s['id'] }).to match_array(stages.map(&:id))
    end
    
    it 'returns stages ordered by position' do
      stages[0].update!(position: 3)
      stages[1].update!(position: 1)
      stages[2].update!(position: 2)
      
      get :index, params: { account_id: account.id }
      
      positions = json_response.map { |s| s['position'] }
      expect(positions).to eq([1, 2, 3])
    end
    
    it 'includes conversation counts when requested' do
      stage = stages.first
      create_list(:conversation, 2, account: account, kanban_stage: stage)
      
      get :index, params: { account_id: account.id, include_counts: true }
      
      stage_data = json_response.find { |s| s['id'] == stage.id }
      expect(stage_data['conversations_count']).to eq(2)
    end
  end
  
  describe 'POST #create' do
    let(:valid_params) do
      {
        account_id: account.id,
        kanban_stage: {
          name: 'New Stage',
          color: '#ff0000',
          position: 4
        }
      }
    end
    
    context 'with valid parameters' do
      it 'creates a new stage' do
        expect {
          post :create, params: valid_params
        }.to change(KanbanStage, :count).by(1)
        
        expect(response).to have_http_status(:created)
        expect(json_response['name']).to eq('New Stage')
        expect(json_response['color']).to eq('#ff0000')
      end
      
      it 'broadcasts the stage creation' do
        expect {
          post :create, params: valid_params
        }.to have_broadcasted_to("account_#{account.id}_kanban")
      end
    end
    
    context 'with invalid parameters' do
      it 'returns validation errors for missing name' do
        post :create, params: { 
          account_id: account.id, 
          kanban_stage: { color: '#ff0000' } 
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include('name')
      end
      
      it 'returns validation errors for invalid color' do
        post :create, params: { 
          account_id: account.id, 
          kanban_stage: { name: 'Test', color: 'invalid' } 
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include('color')
      end
    end
    
    context 'with duplicate name' do
      it 'returns validation error' do
        post :create, params: { 
          account_id: account.id, 
          kanban_stage: { name: stages.first.name, color: '#ff0000' } 
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']['name']).to include('has already been taken')
      end
    end
    
    context 'with XSS attempt' do
      it 'sanitizes malicious input' do
        post :create, params: { 
          account_id: account.id, 
          kanban_stage: { 
            name: '<script>alert("xss")</script>Test',
            color: '#ff0000'
          } 
        }
        
        if response.status == 201
          expect(json_response['name']).not_to include('<script>')
          expect(json_response['name']).to eq('Test')
        else
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end
  
  describe 'PATCH #reorder' do
    let(:positions) do
      [
        { id: stages[0].id, position: 3 },
        { id: stages[1].id, position: 1 },
        { id: stages[2].id, position: 2 }
      ]
    end
    
    it 'reorders stages successfully' do
      patch :reorder, params: { 
        account_id: account.id, 
        positions: positions 
      }
      
      expect(response).to have_http_status(:ok)
      
      stages.each(&:reload)
      expect(stages[0].position).to eq(3)
      expect(stages[1].position).to eq(1)
      expect(stages[2].position).to eq(2)
    end
    
    it 'maintains position uniqueness' do
      patch :reorder, params: { 
        account_id: account.id, 
        positions: positions 
      }
      
      stages.each(&:reload)
      positions_array = stages.map(&:position).sort
      expect(positions_array).to eq([1, 2, 3])
    end
    
    it 'returns error for invalid stage ID' do
      positions[0][:id] = 999999
      
      patch :reorder, params: { 
        account_id: account.id, 
        positions: positions 
      }
      
      expect(response).to have_http_status(:not_found)
    end
    
    it 'handles concurrent reorder attempts' do
      # Simulate concurrent requests
      threads = []
      results = []
      
      2.times do |i|
        threads << Thread.new do
          positions_copy = positions.map { |p| p.dup }
          positions_copy[0][:position] = i + 1
          
          post :reorder, params: { 
            account_id: account.id, 
            positions: positions_copy 
          }
          results << response.status
        end
      end
      
      threads.each(&:join)
      
      # At least one should succeed
      expect(results).to include(200)
    end
  end
  
  describe 'DELETE #destroy' do
    let(:stage) { stages.first }
    
    context 'when stage has no conversations' do
      it 'deletes the stage successfully' do
        expect {
          delete :destroy, params: { account_id: account.id, id: stage.id }
        }.to change(KanbanStage, :count).by(-1)
        
        expect(response).to have_http_status(:no_content)
      end
    end
    
    context 'when stage has conversations' do
      before do
        create(:conversation, account: account, kanban_stage: stage)
      end
      
      it 'prevents deletion and returns error' do
        expect {
          delete :destroy, params: { account_id: account.id, id: stage.id }
        }.not_to change(KanbanStage, :count)
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('Cannot delete stage with conversations')
      end
    end
  end
  
  describe 'authorization' do
    context 'when user is not administrator' do
      let(:agent_user) { create(:user, :agent, account: account) }
      
      before do
        allow(controller).to receive(:current_user).and_return(agent_user)
      end
      
      it 'allows viewing stages' do
        get :index, params: { account_id: account.id }
        expect(response).to have_http_status(:ok)
      end
      
      it 'denies create access' do
        post :create, params: { 
          account_id: account.id, 
          kanban_stage: { name: 'Test', color: '#ff0000' } 
        }
        
        expect(response).to have_http_status(:forbidden)
      end
      
      it 'denies update access' do
        patch :update, params: { 
          account_id: account.id, 
          id: stages.first.id,
          kanban_stage: { name: 'Updated' } 
        }
        
        expect(response).to have_http_status(:forbidden)
      end
    end
    
    context 'when user belongs to different account' do
      let(:other_account) { create(:account) }
      let(:other_user) { create(:user, :administrator, account: other_account) }
      
      before do
        allow(controller).to receive(:current_user).and_return(other_user)
      end
      
      it 'denies access to stages' do
        get :index, params: { account_id: account.id }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
```

---

## Frontend Testing Strategy

### Component Tests

#### KanbanBoard Component Tests

```javascript
// app/javascript/dashboard/routes/dashboard/kanban/KanbanBoard.spec.js
import { mount } from '@vue/test-utils'
import { createStore } from 'vuex'
import { createRouter, createWebHistory } from 'vue-router'
import KanbanBoard from './KanbanBoard.vue'
import kanbanModule from '../../../store/modules/kanban'

describe('KanbanBoard', () => {
  let store
  let router
  let wrapper

  const mockStages = [
    { id: 1, name: 'New', color: '#3b82f6', position: 1 },
    { id: 2, name: 'In Progress', color: '#f59e0b', position: 2 },
    { id: 3, name: 'Resolved', color: '#10b981', position: 3 }
  ]

  const mockConversations = {
    1: [
      { id: 1, subject: 'Test Conversation 1', contact: { name: 'John Doe' } },
      { id: 2, subject: 'Test Conversation 2', contact: { name: 'Jane Smith' } }
    ],
    2: [
      { id: 3, subject: 'Test Conversation 3', contact: { name: 'Bob Wilson' } }
    ],
    3: [],
    unassigned: [
      { id: 4, subject: 'Unassigned Conversation', contact: { name: 'Alice Brown' } }
    ]
  }

  beforeEach(() => {
    store = createStore({
      modules: {
        kanban: {
          ...kanbanModule,
          state: {
            ...kanbanModule.state,
            stages: mockStages,
            conversationsByStage: mockConversations
          }
        },
        accounts: {
          namespaced: true,
          getters: {
            getAccount: () => ({ id: 1, name: 'Test Account' })
          }
        }
      }
    })

    router = createRouter({
      history: createWebHistory(),
      routes: [{ path: '/', component: { template: '<div></div>' } }]
    })

    wrapper = mount(KanbanBoard, {
      global: {
        plugins: [store, router],
        stubs: {
          KanbanFilterBar: {
            template: '<div data-testid="filter-bar"></div>',
            emits: ['filter-change', 'clear-filters']
          },
          KanbanStageColumn: {
            template: '<div data-testid="stage-column"></div>',
            props: ['stage', 'conversations', 'loading'],
            emits: ['load-more', 'conversation-drop', 'conversation-click']
          },
          LoadingOverlay: {
            template: '<div data-testid="loading-overlay"></div>'
          }
        }
      }
    })
  })

  afterEach(() => {
    wrapper.unmount()
  })

  describe('initialization', () => {
    it('renders the kanban board container', () => {
      expect(wrapper.find('.kanban-board-container').exists()).toBe(true)
    })

    it('renders stage columns for each stage plus unassigned', () => {
      const stageColumns = wrapper.findAll('[data-testid="stage-column"]')
      expect(stageColumns).toHaveLength(4) // 3 stages + unassigned
    })

    it('renders filter bar', () => {
      expect(wrapper.find('[data-testid="filter-bar"]').exists()).toBe(true)
    })

    it('dispatches initial data fetch on mount', async () => {
      const dispatchSpy = jest.spyOn(store, 'dispatch')
      
      // Re-mount to trigger onMounted
      wrapper.unmount()
      wrapper = mount(KanbanBoard, {
        global: {
          plugins: [store, router],
          stubs: {
            KanbanFilterBar: true,
            KanbanStageColumn: true,
            LoadingOverlay: true
          }
        }
      })

      await wrapper.vm.$nextTick()

      expect(dispatchSpy).toHaveBeenCalledWith('kanban/fetchStages')
      expect(dispatchSpy).toHaveBeenCalledWith('kanban/fetchConversations', {
        filters: {},
        reset: true
      })
    })
  })

  describe('filter functionality', () => {
    it('updates active filters when filter changes', async () => {
      const filterBar = wrapper.findComponent('[data-testid="filter-bar"]')
      const newFilters = { assignee_id: 1, status: 'open' }

      await filterBar.vm.$emit('filter-change', newFilters)

      expect(wrapper.vm.activeFilters).toEqual(newFilters)
    })

    it('dispatches fetch conversations action when filters change', async () => {
      const dispatchSpy = jest.spyOn(store, 'dispatch')
      const filterBar = wrapper.findComponent('[data-testid="filter-bar"]')

      await filterBar.vm.$emit('filter-change', { status: 'open' })

      expect(dispatchSpy).toHaveBeenCalledWith('kanban/fetchConversations', {
        filters: { status: 'open' },
        reset: true
      })
    })

    it('clears all filters', async () => {
      wrapper.vm.activeFilters = { status: 'open', assignee_id: 1 }
      const filterBar = wrapper.findComponent('[data-testid="filter-bar"]')

      await filterBar.vm.$emit('clear-filters')

      expect(wrapper.vm.activeFilters).toEqual({})
    })
  })

  describe('drag and drop', () => {
    it('handles conversation drop between different stages', async () => {
      const dispatchSpy = jest.spyOn(store, 'dispatch')
      const commitSpy = jest.spyOn(store, 'commit')
      
      const stageColumn = wrapper.findAllComponents('[data-testid="stage-column"]')[0]

      await stageColumn.vm.$emit('conversation-drop', {
        conversationId: 1,
        targetStageId: 2,
        sourceStageId: 1
      })

      // Check optimistic update
      expect(commitSpy).toHaveBeenCalledWith('kanban/moveConversationOptimistic', {
        conversationId: 1,
        targetStageId: 2,
        sourceStageId: 1
      })

      // Check API call
      expect(dispatchSpy).toHaveBeenCalledWith('kanban/updateConversationStage', {
        conversationId: 1,
        stageId: 2
      })
    })

    it('does not handle drop when source and target are the same', async () => {
      const dispatchSpy = jest.spyOn(store, 'dispatch')
      const stageColumn = wrapper.findAllComponents('[data-testid="stage-column"]')[0]

      await stageColumn.vm.$emit('conversation-drop', {
        conversationId: 1,
        targetStageId: 1,
        sourceStageId: 1
      })

      expect(dispatchSpy).not.toHaveBeenCalledWith('kanban/updateConversationStage', expect.anything())
    })

    it('handles drop to unassigned stage', async () => {
      const dispatchSpy = jest.spyOn(store, 'dispatch')
      const stageColumn = wrapper.findAllComponents('[data-testid="stage-column"]')[0]

      await stageColumn.vm.$emit('conversation-drop', {
        conversationId: 1,
        targetStageId: 'unassigned',
        sourceStageId: 1
      })

      expect(dispatchSpy).toHaveBeenCalledWith('kanban/updateConversationStage', {
        conversationId: 1,
        stageId: null
      })
    })
  })

  describe('infinite scrolling', () => {
    it('loads more conversations when load-more is emitted', async () => {
      const dispatchSpy = jest.spyOn(store, 'dispatch')
      const stageColumn = wrapper.findAllComponents('[data-testid="stage-column"]')[0]

      await stageColumn.vm.$emit('load-more', 1)

      expect(dispatchSpy).toHaveBeenCalledWith('kanban/fetchMoreConversations', {
        stageId: 1,
        filters: expect.any(Object)
      })
    })

    it('does not load more if stage is already loading', async () => {
      wrapper.vm.loadingStages.push(1)
      
      const dispatchSpy = jest.spyOn(store, 'dispatch')
      const stageColumn = wrapper.findAllComponents('[data-testid="stage-column"]')[0]

      await stageColumn.vm.$emit('load-more', 1)

      expect(dispatchSpy).not.toHaveBeenCalledWith('kanban/fetchMoreConversations', expect.anything())
    })

    it('manages loading states correctly', async () => {
      expect(wrapper.vm.loadingStages).toEqual([])

      const stageColumn = wrapper.findAllComponents('[data-testid="stage-column"]')[0]
      const loadMorePromise = stageColumn.vm.$emit('load-more', 1)

      expect(wrapper.vm.loadingStages).toContain(1)

      await loadMorePromise
      await wrapper.vm.$nextTick()

      expect(wrapper.vm.loadingStages).not.toContain(1)
    })
  })

  describe('error handling', () => {
    it('shows error state when fetch fails', async () => {
      const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation()
      jest.spyOn(store, 'dispatch').mockRejectedValue(new Error('Network error'))

      await wrapper.vm.handleFilterChange({ status: 'open' })

      expect(consoleErrorSpy).toHaveBeenCalledWith('Filter application failed:', expect.any(Error))
      
      consoleErrorSpy.mockRestore()
    })

    it('rolls back optimistic update on API failure', async () => {
      const commitSpy = jest.spyOn(store, 'commit')
      jest.spyOn(store, 'dispatch').mockRejectedValue(new Error('API error'))

      await wrapper.vm.handleConversationDrop({
        conversationId: 1,
        targetStageId: 2,
        sourceStageId: 1
      })

      expect(commitSpy).toHaveBeenCalledWith('kanban/rollbackConversationMove', {
        conversationId: 1,
        targetStageId: 1,
        sourceStageId: 2
      })
    })

    it('handles network connectivity issues', async () => {
      const originalOnline = navigator.onLine
      Object.defineProperty(navigator, 'onLine', { value: false, writable: true })

      const consoleSpy = jest.spyOn(console, 'warn').mockImplementation()

      await wrapper.vm.handleFilterChange({ status: 'open' })

      expect(consoleSpy).toHaveBeenCalledWith(expect.stringContaining('offline'))

      Object.defineProperty(navigator, 'onLine', { value: originalOnline })
      consoleSpy.mockRestore()
    })
  })

  describe('navigation', () => {
    it('navigates to conversation with correct params', async () => {
      const routerPushSpy = jest.spyOn(router, 'push')
      const stageColumn = wrapper.findAllComponents('[data-testid="stage-column"]')[0]

      await stageColumn.vm.$emit('conversation-click', 123)

      expect(routerPushSpy).toHaveBeenCalledWith({
        name: 'conversation_through_kanban',
        params: { conversation_id: 123 },
        query: { from: 'kanban' }
      })
    })
  })

  describe('real-time updates', () => {
    it('subscribes to kanban updates on mount', async () => {
      const dispatchSpy = jest.spyOn(store, 'dispatch')

      // Re-mount to trigger subscription
      wrapper.unmount()
      wrapper = mount(KanbanBoard, {
        global: {
          plugins: [store, router],
          stubs: {
            KanbanFilterBar: true,
            KanbanStageColumn: true,
            LoadingOverlay: true
          }
        }
      })

      await wrapper.vm.$nextTick()

      expect(dispatchSpy).toHaveBeenCalledWith('kanban/subscribeToUpdates', {
        accountId: 1
      })
    })
  })

  describe('performance', () => {
    it('debounces filter changes', async () => {
      jest.useFakeTimers()
      const dispatchSpy = jest.spyOn(store, 'dispatch')
      const filterBar = wrapper.findComponent('[data-testid="filter-bar"]')

      // Emit multiple filter changes rapidly
      filterBar.vm.$emit('filter-change', { status: 'open' })
      filterBar.vm.$emit('filter-change', { status: 'closed' })
      filterBar.vm.$emit('filter-change', { status: 'pending' })

      // Should only dispatch once after debounce
      expect(dispatchSpy).toHaveBeenCalledTimes(1)

      jest.useRealTimers()
    })

    it('handles large conversation lists efficiently', async () => {
      const performanceMark = jest.spyOn(performance, 'mark').mockImplementation()
      const performanceMeasure = jest.spyOn(performance, 'measure').mockImplementation()

      // Simulate large conversation list
      const largeConversationsList = Array.from({ length: 1000 }, (_, i) => ({
        id: i,
        subject: `Conversation ${i}`,
        contact: { name: `Contact ${i}` }
      }))

      store.commit('kanban/SET_KANBAN_CONVERSATIONS', {
        1: largeConversationsList
      })

      await wrapper.vm.$nextTick()

      expect(performanceMark).toHaveBeenCalled()
      expect(performanceMeasure).toHaveBeenCalled()

      performanceMark.mockRestore()
      performanceMeasure.mockRestore()
    })
  })
})
```

---

## Integration Testing

### API Integration Tests

```ruby
# spec/requests/api/v1/kanban_integration_spec.rb
require 'rails_helper'

RSpec.describe 'Kanban API Integration', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, :administrator, account: account) }
  let(:headers) { { 'Authorization' => "Bearer #{user.access_token}" } }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:current_account).and_return(account)
  end

  describe 'Complete Kanban workflow' do
    it 'supports full kanban board management' do
      # Create stages
      stage1_response = post "/api/v1/accounts/#{account.id}/kanban_stages", 
        params: { kanban_stage: { name: 'To Do', color: '#ff0000', position: 1 } },
        headers: headers
      
      expect(stage1_response).to eq(201)
      stage1_id = JSON.parse(response.body)['id']

      stage2_response = post "/api/v1/accounts/#{account.id}/kanban_stages", 
        params: { kanban_stage: { name: 'In Progress', color: '#00ff00', position: 2 } },
        headers: headers
      
      expect(stage2_response).to eq(201)
      stage2_id = JSON.parse(response.body)['id']

      # Create conversations
      conversation1 = create(:conversation, account: account)
      conversation2 = create(:conversation, account: account)

      # Move conversations to stages
      patch "/api/v1/accounts/#{account.id}/conversations/#{conversation1.id}/kanban_stage",
        params: { kanban_stage_id: stage1_id },
        headers: headers
      
      expect(response).to have_http_status(:ok)

      patch "/api/v1/accounts/#{account.id}/conversations/#{conversation2.id}/kanban_stage",
        params: { kanban_stage_id: stage2_id },
        headers: headers
      
      expect(response).to have_http_status(:ok)

      # Get kanban board
      get "/api/v1/accounts/#{account.id}/conversations/kanban_board", headers: headers
      
      expect(response).to have_http_status(:ok)
      board_data = JSON.parse(response.body)
      
      expect(board_data['stages']).to have(2).items
      expect(board_data['conversations_by_stage'][stage1_id.to_s]).to have(1).item
      expect(board_data['conversations_by_stage'][stage2_id.to_s]).to have(1).item

      # Reorder stages
      patch "/api/v1/accounts/#{account.id}/kanban_stages/reorder",
        params: { 
          positions: [
            { id: stage1_id, position: 2 },
            { id: stage2_id, position: 1 }
          ]
        },
        headers: headers
      
      expect(response).to have_http_status(:ok)

      # Verify reorder
      get "/api/v1/accounts/#{account.id}/kanban_stages", headers: headers
      stages = JSON.parse(response.body).sort_by { |s| s['position'] }
      
      expect(stages.first['id']).to eq(stage2_id)
      expect(stages.last['id']).to eq(stage1_id)
    end

    it 'handles concurrent operations correctly' do
      stage = create(:kanban_stage, account: account)
      conversations = create_list(:conversation, 5, account: account)

      # Simulate concurrent stage moves
      threads = conversations.map.with_index do |conversation, index|
        Thread.new do
          sleep(rand(0.1)) # Random delay
          
          patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.id}/kanban_stage",
            params: { kanban_stage_id: stage.id },
            headers: headers
        end
      end

      threads.each(&:join)

      # Verify all conversations moved
      get "/api/v1/accounts/#{account.id}/conversations/kanban_board", headers: headers
      board_data = JSON.parse(response.body)
      
      expect(board_data['conversations_by_stage'][stage.id.to_s]).to have(5).items
    end
  end

  describe 'Performance testing' do
    it 'handles large datasets efficiently' do
      # Create many stages and conversations
      stages = create_list(:kanban_stage, 10, account: account)
      conversations = create_list(:conversation, 100, account: account)

      # Assign conversations to stages
      conversations.each_with_index do |conversation, index|
        stage = stages[index % stages.length]
        conversation.update!(kanban_stage: stage)
      end

      # Measure response time
      start_time = Time.current
      
      get "/api/v1/accounts/#{account.id}/conversations/kanban_board", headers: headers
      
      response_time = Time.current - start_time
      
      expect(response).to have_http_status(:ok)
      expect(response_time).to be < 2.seconds
      
      board_data = JSON.parse(response.body)
      expect(board_data['conversations_by_stage'].values.flatten).to have(100).items
    end

    it 'respects rate limits' do
      # Attempt to exceed rate limit
      20.times do
        post "/api/v1/accounts/#{account.id}/kanban_stages", 
          params: { kanban_stage: { name: "Stage #{rand(1000)}", color: '#ff0000' } },
          headers: headers
      end

      # Should eventually get rate limited
      expect(response.status).to be_in([201, 429])
    end
  end

  describe 'Error handling' do
    it 'handles invalid stage assignments gracefully' do
      conversation = create(:conversation, account: account)
      invalid_stage_id = 999999

      patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.id}/kanban_stage",
        params: { kanban_stage_id: invalid_stage_id },
        headers: headers
      
      expect(response).to have_http_status(:not_found)
      
      error_data = JSON.parse(response.body)
      expect(error_data['error']).to include('not found')
    end

    it 'prevents unauthorized access to other accounts' do
      other_account = create(:account)
      other_stage = create(:kanban_stage, account: other_account)

      get "/api/v1/accounts/#{other_account.id}/kanban_stages", headers: headers
      
      expect(response).to have_http_status(:forbidden)
    end
  end
end
```

---

## End-to-End Testing

### E2E Test Suite

```javascript
// spec/system/kanban_board_spec.js
import { test, expect } from '@playwright/test'

test.describe('Kanban Board E2E', () => {
  test.beforeEach(async ({ page }) => {
    // Setup test data and login
    await page.goto('/app/accounts/1/dashboard/kanban')
    await page.waitForLoadState('networkidle')
  })

  test('displays stages and conversations correctly', async ({ page }) => {
    // Check stage columns are visible
    await expect(page.locator('[data-testid="stage-column"]')).toHaveCount(4)
    
    // Check stage names
    await expect(page.locator('[data-testid="stage-title"]').first()).toHaveText('New')
    
    // Check conversation cards are visible
    await expect(page.locator('[data-testid="conversation-card"]')).toHaveCount.greaterThan(0)
  })

  test('can drag and drop conversations between stages', async ({ page }) => {
    const sourceCard = page.locator('[data-testid="conversation-card"]').first()
    const targetStage = page.locator('[data-testid="stage-column"]').nth(1)

    // Get initial stage for verification
    const sourceStage = page.locator('[data-testid="stage-column"]').first()
    const initialCount = await sourceStage.locator('[data-testid="conversation-count"]').textContent()

    // Perform drag and drop
    await sourceCard.dragTo(targetStage)

    // Wait for optimistic update
    await page.waitForTimeout(500)

    // Verify the conversation moved (optimistic update)
    const newCount = await sourceStage.locator('[data-testid="conversation-count"]').textContent()
    expect(parseInt(newCount)).toBe(parseInt(initialCount) - 1)
  })

  test('can filter conversations', async ({ page }) => {
    // Open filter dropdown
    await page.click('[data-testid="filter-assignee"]')
    
    // Select an assignee
    await page.click('[data-testid="assignee-option"]')
    
    // Wait for filtered results
    await page.waitForLoadState('networkidle')
    
    // Verify filter chip is shown
    await expect(page.locator('[data-testid="filter-chip"]')).toBeVisible()
    
    // Verify conversations are filtered
    const conversationCards = page.locator('[data-testid="conversation-card"]')
    await expect(conversationCards).toHaveCount.greaterThan(0)
  })

  test('can create a new stage', async ({ page }) => {
    await page.click('[data-testid="kanban-settings-link"]')
    await page.click('[data-testid="create-stage-button"]')
    
    // Fill stage form
    await page.fill('[data-testid="stage-name-input"]', 'Testing Stage')
    await page.click('[data-testid="color-option-red"]')
    
    // Save stage
    await page.click('[data-testid="save-stage-button"]')
    
    // Wait for creation and navigation back
    await page.waitForLoadState('networkidle')
    
    // Verify new stage appears
    await expect(page.locator('[data-testid="stage-title"]').last()).toHaveText('Testing Stage')
  })

  test('shows loading states appropriately', async ({ page }) => {
    // Trigger infinite scroll
    await page.locator('[data-testid="stage-column"]').first().hover()
    await page.mouse.wheel(0, 1000)
    
    // Check loading skeleton appears
    await expect(page.locator('[data-testid="conversation-skeleton"]')).toBeVisible()
    
    // Wait for loading to complete
    await page.waitForLoadState('networkidle')
    
    // Verify skeleton is hidden
    await expect(page.locator('[data-testid="conversation-skeleton"]')).not.toBeVisible()
  })

  test('handles real-time updates', async ({ page, context }) => {
    // Open a second page to simulate another user
    const page2 = await context.newPage()
    await page2.goto('/app/accounts/1/dashboard/kanban')
    await page2.waitForLoadState('networkidle')

    // Create a new stage from page2
    await page2.click('[data-testid="kanban-settings-link"]')
    await page2.click('[data-testid="create-stage-button"]')
    await page2.fill('[data-testid="stage-name-input"]', 'Real-time Test')
    await page2.click('[data-testid="save-stage-button"]')

    // Verify the new stage appears on page1 via real-time update
    await expect(page.locator('[data-testid="stage-title"]')).toContainText('Real-time Test')
  })

  test('handles network failures gracefully', async ({ page, context }) => {
    // Simulate network failure
    await context.setOffline(true)
    
    // Try to perform an action
    await page.click('[data-testid="filter-assignee"]')
    
    // Should show offline indicator
    await expect(page.locator('[data-testid="offline-indicator"]')).toBeVisible()
    
    // Restore network
    await context.setOffline(false)
    
    // Should recover automatically
    await expect(page.locator('[data-testid="offline-indicator"]')).not.toBeVisible()
  })

  test('supports keyboard navigation', async ({ page }) => {
    // Focus on first conversation card
    await page.locator('[data-testid="conversation-card"]').first().focus()
    
    // Navigate with arrow keys
    await page.keyboard.press('ArrowDown')
    await page.keyboard.press('ArrowDown')
    
    // Open conversation with Enter
    await page.keyboard.press('Enter')
    
    // Should navigate to conversation view
    await expect(page).toHaveURL(/.*\/conversations\/\d+/)
  })

  test('performs well with large datasets', async ({ page }) => {
    // Navigate to account with large dataset
    await page.goto('/app/accounts/2/dashboard/kanban') // Account with 1000+ conversations
    
    // Measure initial load time
    const startTime = Date.now()
    await page.waitForLoadState('networkidle')
    const loadTime = Date.now() - startTime
    
    expect(loadTime).toBeLessThan(5000) // Should load within 5 seconds
    
    // Test scrolling performance
    const stageColumn = page.locator('[data-testid="stage-column"]').first()
    
    for (let i = 0; i < 10; i++) {
      await stageColumn.hover()
      await page.mouse.wheel(0, 500)
      await page.waitForTimeout(100)
    }
    
    // Should still be responsive
    await expect(stageColumn).toBeVisible()
  })
})
```

---

## Performance Testing

### Load Testing

```ruby
# spec/performance/kanban_load_spec.rb
require 'rails_helper'

RSpec.describe 'Kanban Load Testing', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, :administrator, account: account) }
  let(:headers) { { 'Authorization' => "Bearer #{user.access_token}" } }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:current_account).and_return(account)
  end

  describe 'Kanban board performance' do
    context 'with large dataset' do
      before do
        # Create realistic test data
        @stages = create_list(:kanban_stage, 8, account: account)
        @conversations = create_list(:conversation, 500, account: account)
        
        # Distribute conversations across stages
        @conversations.each_with_index do |conversation, index|
          stage = @stages[index % @stages.length]
          conversation.update!(kanban_stage: stage)
        end
      end

      it 'loads kanban board within acceptable time' do
        times = []
        
        10.times do
          start_time = Time.current
          get "/api/v1/accounts/#{account.id}/conversations/kanban_board", headers: headers
          end_time = Time.current
          
          expect(response).to have_http_status(:ok)
          times << (end_time - start_time)
        end
        
        avg_time = times.sum / times.length
        max_time = times.max
        
        expect(avg_time).to be < 1.second
        expect(max_time).to be < 2.seconds
        
        puts "Average response time: #{avg_time.round(3)}s"
        puts "Max response time: #{max_time.round(3)}s"
      end

      it 'handles concurrent requests efficiently' do
        threads = []
        results = []
        
        20.times do
          threads << Thread.new do
            start_time = Time.current
            get "/api/v1/accounts/#{account.id}/conversations/kanban_board", headers: headers
            end_time = Time.current
            
            results << {
              status: response.status,
              time: end_time - start_time
            }
          end
        end
        
        threads.each(&:join)
        
        successful_requests = results.count { |r| r[:status] == 200 }
        avg_time = results.map { |r| r[:time] }.sum / results.length
        
        expect(successful_requests).to eq(20)
        expect(avg_time).to be < 3.seconds
        
        puts "Concurrent requests - Success rate: #{(successful_requests / 20.0 * 100).round(1)}%"
        puts "Concurrent requests - Average time: #{avg_time.round(3)}s"
      end
    end
  end

  describe 'Stage operations performance' do
    it 'creates stages efficiently' do
      times = []
      
      20.times do |i|
        start_time = Time.current
        post "/api/v1/accounts/#{account.id}/kanban_stages", 
          params: { kanban_stage: { name: "Stage #{i}", color: '#ff0000', position: i + 1 } },
          headers: headers
        end_time = Time.current
        
        expect(response.status).to be_in([201, 429]) # 429 for rate limiting
        times << (end_time - start_time) if response.status == 201
      end
      
      avg_time = times.sum / times.length if times.any?
      
      expect(avg_time).to be < 0.5.seconds if avg_time
      puts "Stage creation average time: #{avg_time&.round(3)}s"
    end
  end

  describe 'Memory usage' do
    it 'does not leak memory during extended usage' do
      initial_memory = memory_usage
      
      100.times do
        get "/api/v1/accounts/#{account.id}/conversations/kanban_board", headers: headers
        
        # Trigger garbage collection every 10 requests
        GC.start if (Time.current.to_i % 10).zero?
      end
      
      final_memory = memory_usage
      memory_increase = final_memory - initial_memory
      
      expect(memory_increase).to be < 50 # Less than 50MB increase
      puts "Memory increase: #{memory_increase.round(2)}MB"
    end
  end

  private

  def memory_usage
    `ps -o rss -p #{Process.pid}`.strip.split.last.to_i / 1024.0
  rescue
    0
  end
end
```

---

## Implementation Checklist

### Backend Testing
- [ ] Model unit tests with comprehensive validation coverage
- [ ] Controller tests with authorization and error scenarios
- [ ] Service layer tests for business logic
- [ ] Policy tests for access control
- [ ] Integration tests for complete workflows
- [ ] Performance tests for large datasets

### Frontend Testing
- [ ] Component unit tests with all user interactions
- [ ] Vuex store tests for state management
- [ ] Composable tests for reusable logic
- [ ] Integration tests for component interaction
- [ ] E2E tests for complete user journeys
- [ ] Performance tests for large conversation lists

### Real-time Testing
- [ ] WebSocket connection tests
- [ ] Event broadcasting tests
- [ ] Multi-user real-time scenario tests
- [ ] Connection failure recovery tests
- [ ] Message ordering and delivery tests

### Security Testing
- [ ] Authorization boundary tests
- [ ] Input sanitization tests
- [ ] XSS and injection prevention tests
- [ ] Rate limiting effectiveness tests
- [ ] Data privacy compliance tests

### Performance Testing
- [ ] Load testing with realistic data volumes
- [ ] Concurrent user simulation
- [ ] Memory leak detection
- [ ] Database query performance tests
- [ ] Frontend rendering performance tests

---

## Integration Points

**Testing Dependencies:**
- ✅ Requires implemented features from all other shards
- ✅ Backend tests need [Backend Core](./02-backend-core.md) implementation
- ✅ Frontend tests need [Frontend Components](./03-frontend-components.md) implementation
- ✅ Security tests need [Security Implementation](./05-security-implementation.md)
- ✅ Performance tests need [Performance Optimization](./06-performance-optimization.md)

**Related Documents:**
- [Backend Core Implementation](./02-backend-core.md)
- [Frontend Components Guide](./03-frontend-components.md)
- [Security Implementation Guide](./05-security-implementation.md)
- [Performance Optimization Guide](./06-performance-optimization.md)
- [Deployment & Monitoring Guide](./08-deployment-monitoring.md)