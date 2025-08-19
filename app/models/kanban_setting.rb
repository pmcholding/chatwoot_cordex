# frozen_string_literal: true

# == Schema Information
#
# Table name: kanban_settings
#
#  id                        :bigint           not null, primary key
#  auto_assign_conversations :boolean          default(FALSE), not null
#  default_filters           :jsonb            not null
#  show_conversation_count   :boolean          default(TRUE), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#  default_stage_id          :bigint
#
# Indexes
#
#  index_kanban_settings_on_account_id        (account_id) UNIQUE
#  index_kanban_settings_on_default_stage_id  (default_stage_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (default_stage_id => kanban_stages.id) ON DELETE => nullify
#
class KanbanSetting < ApplicationRecord
  belongs_to :account
  belongs_to :default_stage, class_name: 'KanbanStage', optional: true

  # Allow empty JSON object for default_filters

  def self.for_account!(account)
    find_or_create_by!(account: account) do |rec|
      rec.auto_assign_conversations = false
      rec.show_conversation_count = true
      rec.default_filters = {}
    end
  end
end
