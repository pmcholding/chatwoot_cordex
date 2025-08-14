class AgentTemplate < ApplicationRecord
  belongs_to :account, optional: true

  validates :name, presence: true, length: { maximum: 255 }
  validates :instructions, presence: true

  scope :global, -> { where(account_id: nil) }
  scope :for_account, ->(account) { where(account: account) }
  scope :available_for, ->(account) { where(account: [account, nil]) }
end
