class ScheduledMessageJob < ApplicationJob
  queue_as :default

  def perform
    ScheduledMessage.ready_to_send.find_each do |scheduled_message|
      next if scheduled_message.cancelled?

      begin
        conversation = scheduled_message.conversation
        message = conversation.messages.create!(
          content: scheduled_message.content,
          account: conversation.account,
          inbox: conversation.inbox,
          sender: scheduled_message.user,
          message_type: :outgoing
        )

        scheduled_message.update!(status: :sent, metadata: { message_id: message.id })
      rescue => e
        scheduled_message.update!(status: :failed, metadata: { error: e.message })
        Rails.logger.error "Failed to send scheduled message #{scheduled_message.id}: #{e.message}"
      end
    end
  end
end

