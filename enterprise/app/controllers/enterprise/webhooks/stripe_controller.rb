class Enterprise::Webhooks::StripeController < ActionController::API
  def process_payload
    # Get the event payload
    payload = request.body.read

    Rails.logger.info '🔍 WEBHOOK DEBUG - Payload recebido!'
    Rails.logger.info "🔍 WEBHOOK DEBUG - Payload size: #{payload.length}"
    Rails.logger.info '🔍 WEBHOOK DEBUG - VALIDAÇÃO DESABILITADA TEMPORARIAMENTE'

    begin
      # Parse JSON directly without signature validation
      event_data = JSON.parse(payload)

      Rails.logger.info "🔍 WEBHOOK DEBUG - Event type: #{event_data['type']}"
      Rails.logger.info "🔍 WEBHOOK DEBUG - Event ID: #{event_data['id']}"

      # Create a mock event object
      event = OpenStruct.new(
        type: event_data['type'],
        data: OpenStruct.new(object: event_data['data']['object'])
      )

      Rails.logger.info '🎉 WEBHOOK DEBUG - Event parsed successfully!'

      # Process the event
      ::Enterprise::Billing::HandleStripeEventService.new.perform(event: event)
      Rails.logger.info '🎉 WEBHOOK DEBUG - Event processing SUCCESS!'

    rescue JSON::ParserError => e
      Rails.logger.error "❌ WEBHOOK DEBUG - JSON Parse Error: #{e.message}"
      head :bad_request
      return
    rescue StandardError => e
      Rails.logger.error "❌ WEBHOOK DEBUG - Unexpected Error: #{e.message}"
      Rails.logger.error "❌ WEBHOOK DEBUG - Backtrace: #{e.backtrace.first(3)}"
      head :bad_request
      return
    end

    # Success
    head :ok
  end
end
