class CreateKanbanStages < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_stages do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false, limit: 255
      t.string :color, null: false, default: '#6366f1', limit: 7
      t.integer :position, null: false

      t.timestamps null: false
    end

    # Performance indexes
    add_index :kanban_stages, [:account_id, :position],
              name: 'idx_kanban_stages_account_position', unique: true
    add_index :kanban_stages, :account_id,
              name: 'idx_kanban_stages_account_id'

    # Unique constraints
    add_index :kanban_stages, [:account_id, :name],
              name: 'unique_stage_name_per_account', unique: true

    # Check constraint for color format
    execute <<-SQL
      ALTER TABLE kanban_stages
      ADD CONSTRAINT valid_color_format
      CHECK (color ~ '^#[0-9A-Fa-f]{6}$')
    SQL
  end
end
