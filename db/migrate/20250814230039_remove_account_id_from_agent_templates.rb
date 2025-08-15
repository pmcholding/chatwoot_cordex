class RemoveAccountIdFromAgentTemplates < ActiveRecord::Migration[7.1]
  def change
    # Remove the composite index first
    remove_index :agent_templates, [:language, :account_id] if index_exists?(:agent_templates, [:language, :account_id])

    # Remove the account_id column
    remove_column :agent_templates, :account_id, :integer
  end
end
