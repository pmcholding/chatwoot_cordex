# == Schema Information
#
# Table name: scheduled_messages
#
#  id              :bigint           not null, primary key
#  content         :text             not null
#  metadata        :jsonb
#  scheduled_at    :datetime         not null
#  status          :integer          default("pending")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  conversation_id :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  idx_sched_msgs_status_time                   (status,scheduled_at)
#  index_scheduled_messages_on_conversation_id  (conversation_id)
#  index_scheduled_messages_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (user_id => users.id)
#
class ScheduledMessage < ApplicationRecord
  belongs_to :conversation
  belongs_to :user

  validates :content, presence: true
  validates :scheduled_at, presence: true
  validate :scheduled_at_in_future

  enum status: { pending: 0, sent: 1, cancelled: 2, failed: 3 }

  scope :ready_to_send, -> { pending.where('scheduled_at <= ?', Time.current) }

  private

  def scheduled_at_in_future
    return if scheduled_at.blank?
    errors.add(:scheduled_at, 'must be in the future') if scheduled_at < Time.current
  end
end

