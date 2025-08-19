# frozen_string_literal: true

class AddMoreDefaultKanbanStages < ActiveRecord::Migration[7.0]
  def up
    # Add new stages for existing accounts that don't have them
    Account.includes(:kanban_stages).find_each do |account|
      existing_stages = account.kanban_stages.pluck(:name)

      # New stages to add
      new_stages = [
        { name: 'Closed', color: '#6b7280', position: 5 },
        { name: 'Blocked', color: '#ef4444', position: 6 },
        { name: 'Testing', color: '#06b6d4', position: 7 },
        { name: 'Approved', color: '#84cc16', position: 8 }
      ]

      new_stages.each do |stage_attrs|
        next if existing_stages.include?(stage_attrs[:name])

        # Find the next available position
        max_position = account.kanban_stages.maximum(:position) || 0
        stage_attrs[:position] = max_position + 1

        account.kanban_stages.create!(stage_attrs)
      end
    end
  end

  def down
    # Remove the newly added stages
    stage_names = %w[Closed Blocked Testing Approved]
    KanbanStage.where(name: stage_names).destroy_all
  end
end
