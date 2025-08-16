# Kanban Backend Implementation

## Overview

This document describes the backend implementation for the Chatwoot Kanban system that connects conversations to customizable stages for better workflow management.

## Database Schema

### Tables Created

#### `kanban_stages`
- `id` (bigint, primary key)
- `account_id` (bigint, foreign key to accounts)
- `name` (varchar(255), not null)
- `color` (varchar(7), not null, default '#6366f1')
- `position` (integer, not null)
- `created_at` (timestamp)
- `updated_at` (timestamp)

**Constraints:**
- Unique constraint on `(account_id, name)`
- Unique constraint on `(account_id, position)`
- Check constraint for color format: `^#[0-9A-Fa-f]{6}$`

#### `conversations` (modified)
- Added `kanban_stage_id` (bigint, nullable, foreign key to kanban_stages)

**Indexes:**
- `idx_conversations_account_kanban_stage` on `(account_id, kanban_stage_id)`
- `idx_conversations_kanban_stage_updated` on `(kanban_stage_id, updated_at)`

## Models

### KanbanStage
- Belongs to `account`
- Has many `conversations` (dependent: nullify)
- Validates name presence and uniqueness per account
- Validates color format (hex color)
- Validates position uniqueness per account
- Auto-sets position for new stages
- Provides default stages creation method

### Conversation (extended)
- Belongs to `kanban_stage` (optional)
- Added methods:
  - `move_to_kanban_stage!(stage)` - Move conversation to a stage
  - `kanban_stage_name` - Get stage name or 'Unassigned'
  - `kanban_stage_color` - Get stage color or default
  - `kanban_board_data(account, filters)` - Class method to get board data

### Account (extended)
- Has many `kanban_stages` (dependent: destroy_async)

## API Endpoints

### KanbanStages Controller (`/api/v1/accounts/:account_id/kanban_stages`)

- `GET /` - List all stages with optional conversation counts
- `POST /` - Create a new stage
- `GET /:id` - Show specific stage
- `PATCH /:id` - Update stage
- `DELETE /:id` - Delete stage
- `PATCH /reorder` - Reorder stages
- `GET /board_data` - Get complete kanban board data with conversations

### Conversations Kanban Controller (`/api/v1/accounts/:account_id/conversations/:conversation_id/kanban`)

- `PATCH /move` - Move conversation to different stage
- `PATCH /bulk_move` - Bulk move multiple conversations

## Frontend Integration

### API Client (`app/javascript/dashboard/api/kanban.js`)
- Provides methods for all kanban operations
- Handles authentication and error handling
- Returns promises for async operations

### Vuex Store (`app/javascript/dashboard/store/modules/kanban.js`)
- Manages kanban state (stages, conversations, filters)
- Provides actions for fetching, creating, updating, deleting
- Handles optimistic updates for drag & drop
- Integrates with real API endpoints

## Usage Examples

### Creating Default Stages
```ruby
# For new accounts
KanbanStage.create_default_stages_for_account!(account)

# Default stages created:
# - New (#3b82f6)
# - In Progress (#f59e0b) 
# - Waiting (#8b5cf6)
# - Resolved (#10b981)
```

### Moving Conversations
```ruby
conversation = Conversation.find(123)
stage = account.kanban_stages.find_by(name: 'In Progress')
conversation.move_to_kanban_stage!(stage)
```

### Getting Board Data
```ruby
data = Conversation.kanban_board_data(account, { q: 'search term' })
# Returns: { stages: [...], conversations_by_stage: {...}, total_count: 42 }
```

## Migration Notes

- Tables and columns are created via Rails migrations
- Default stages are created for existing accounts via migration
- Foreign key constraints ensure data integrity
- Indexes optimize kanban queries

## Future Enhancements

- Real-time updates via ActionCable (TODO in broadcast methods)
- Advanced filtering and sorting options
- Stage-based automation rules
- Analytics and reporting for kanban metrics
- Bulk operations for stage management

## Testing

The implementation includes:
- Model validations and associations
- Controller actions with proper error handling
- API integration with frontend store
- Database constraints and indexes

Test the implementation by:
1. Creating stages via API
2. Moving conversations between stages
3. Filtering conversations by stage
4. Reordering stages
