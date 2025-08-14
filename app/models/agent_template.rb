# == Schema Information
#
# Table name: agent_templates
#
#  id           :bigint           not null, primary key
#  description  :text
#  instructions :text             not null
#  name         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint
#
# Indexes
#
#  index_agent_templates_on_account_id  (account_id)
#  index_agent_templates_on_name        (name)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class AgentTemplate < ApplicationRecord
  belongs_to :account, optional: true

  validates :name, presence: true, length: { maximum: 255 }
  validates :instructions, presence: true

  scope :global, -> { where(account_id: nil) }
  scope :for_account, ->(account) { where(account: account) }
  scope :available_for, ->(account) { where(account: [account, nil]) }
end
