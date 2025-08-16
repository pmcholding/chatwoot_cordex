class CreateDefaultKanbanStagesForExistingAccounts < ActiveRecord::Migration[7.1]
  def up
    # Create default kanban stages for all existing accounts
    Account.find_each do |account|
      next if account.kanban_stages.exists?

      default_stages = [
        { name: 'New', color: '#3b82f6', position: 1 },
        { name: 'In Progress', color: '#f59e0b', position: 2 },
        { name: 'Waiting', color: '#8b5cf6', position: 3 },
        { name: 'Resolved', color: '#10b981', position: 4 }
      ]

      default_stages.each do |stage_attrs|
        account.kanban_stages.create!(stage_attrs)
      end
    end
  end

  def down
    # Remove default stages (optional - could be dangerous in production)
    # KanbanStage.where(name: ['New', 'In Progress', 'Waiting', 'Resolved']).destroy_all
  end
end
