class CreateAgentTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_templates do |t|
      t.string :name, null: false
      t.text :description
      t.text :instructions, null: false
      t.references :account, null: true, foreign_key: true

      t.timestamps
    end

    add_index :agent_templates, :name
  end
end
