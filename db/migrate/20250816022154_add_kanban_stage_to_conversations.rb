class AddKanbanStageToConversations < ActiveRecord::Migration[7.1]
  def change
    add_reference :conversations, :kanban_stage, null: true,
                  foreign_key: { on_delete: :nullify }

    # Performance indexes for Kanban queries
    add_index :conversations, [:account_id, :kanban_stage_id],
              name: 'idx_conversations_account_kanban_stage'
    add_index :conversations, [:kanban_stage_id, :updated_at],
              name: 'idx_conversations_kanban_stage_updated'
  end
end
