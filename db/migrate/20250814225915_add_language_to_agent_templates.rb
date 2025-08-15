class AddLanguageToAgentTemplates < ActiveRecord::Migration[7.1]
  def change
    add_column :agent_templates, :language, :string, default: 'en', null: false
    add_index :agent_templates, :language
    add_index :agent_templates, [:language, :account_id]
  end
end
