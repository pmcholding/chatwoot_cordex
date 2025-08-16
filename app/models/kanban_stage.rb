# frozen_string_literal: true

# == Schema Information
#
# Table name: kanban_stages
#
#  id         :bigint           not null, primary key
#  color      :string(7)        default("#6366f1"), not null
#  name       :string(255)      not null
#  position   :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  idx_kanban_stages_account_name_unique      (account_id,name) UNIQUE
#  idx_kanban_stages_account_position         (account_id,position)
#  idx_kanban_stages_account_position_unique  (account_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#
class KanbanStage < ApplicationRecord
  belongs_to :account
  has_many :conversations, dependent: :nullify

  validates :name, presence: true, length: { maximum: 255 }
  validates :name, uniqueness: { scope: :account_id }
  validates :color, presence: true, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }
  validates :position, presence: true, uniqueness: { scope: :account_id }
  validates :position, numericality: { greater_than: 0, less_than_or_equal_to: 20 }

  scope :ordered, -> { order(:position) }
  scope :for_account, ->(account) { where(account: account) }

  before_validation :set_next_position, if: :new_record?
  after_create :broadcast_stage_created
  after_update :broadcast_stage_updated
  after_destroy :broadcast_stage_destroyed

  def conversations_count
    conversations.count
  end

  def self.default_stages_for_account(account)
    [
      { name: 'New', color: '#3b82f6', position: 1 },
      { name: 'In Progress', color: '#f59e0b', position: 2 },
      { name: 'Waiting', color: '#8b5cf6', position: 3 },
      { name: 'Resolved', color: '#10b981', position: 4 }
    ].map { |attrs| account.kanban_stages.build(attrs) }
  end

  def self.create_default_stages_for_account!(account)
    return if account.kanban_stages.exists?

    default_stages_for_account(account).each(&:save!)
  end

  private

  def set_next_position
    return if position.present?

    last_position = account.kanban_stages.maximum(:position) || 0
    self.position = last_position + 1
  end

  def broadcast_stage_created
    # TODO: Implement ActionCable broadcasting for real-time updates
    # ActionCable.server.broadcast(
    #   "kanban_#{account_id}",
    #   { type: 'stage_created', stage: self }
    # )
  end

  def broadcast_stage_updated
    # TODO: Implement ActionCable broadcasting for real-time updates
    # ActionCable.server.broadcast(
    #   "kanban_#{account_id}",
    #   { type: 'stage_updated', stage: self }
    # )
  end

  def broadcast_stage_destroyed
    # TODO: Implement ActionCable broadcasting for real-time updates
    # ActionCable.server.broadcast(
    #   "kanban_#{account_id}",
    #   { type: 'stage_destroyed', stage_id: id }
    # )
  end
end
