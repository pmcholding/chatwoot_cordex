class ScheduledMessageJob < ApplicationJob
  queue_as :default
  
  def perform
    Message.ready_to_send.find_each do |message|
      begin
        # Simply update status to 'sent'
        # This triggers the send_reply automatically via callback after_update_commit
        message.update!(status: :sent)
        
        Rails.logger.info "Scheduled message #{message.id} sent successfully at #{Time.current}"
      rescue => e
        message.update!(status: :failed)
        Rails.logger.error "Failed to send scheduled message #{message.id}: #{e.message}"
      end
    end
  end
end
