class CreateKanbanSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :kanban_settings do |t|
      t.references :account, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.boolean :auto_assign_conversations, null: false, default: false
      t.boolean :show_conversation_count, null: false, default: true
      t.bigint :default_stage_id, null: true
      t.jsonb :default_filters, null: false, default: {}
      t.timestamps
    end

    add_index :kanban_settings, :default_stage_id
    add_foreign_key :kanban_settings, :kanban_stages, column: :default_stage_id, on_delete: :nullify
  end
end
