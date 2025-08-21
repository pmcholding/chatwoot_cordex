class ProcessScheduledMessagesJob < ApplicationJob
  queue_as :default

  def perform
    # Find all scheduled messages that should be sent now
    scheduled_messages = Message.where(
      status: 'scheduled',
      scheduled_at: ..Time.current
    )

    Rails.logger.info "Processing #{scheduled_messages.count} scheduled messages"

    scheduled_messages.find_each do |message|
      begin
        process_scheduled_message(message)
      rescue StandardError => e
        Rails.logger.error "Failed to process scheduled message #{message.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end

  private

  def process_scheduled_message(message)
    Rails.logger.info "Processing scheduled message #{message.id}"

    # Update status to sent
    message.update!(status: 'sent')

    # Trigger the same events that happen when a message is sent
    Rails.application.config.dispatcher.dispatch(
      'message.sent',
      Time.zone.now,
      message: message
    )

    Rails.logger.info "Successfully processed scheduled message #{message.id}"
  end
end
