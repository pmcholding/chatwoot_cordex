class Api::V1::Accounts::Conversations::ScheduledMessagesController < Api::V1::Accounts::Conversations::BaseController
  
  def create
    # Create message normal, but with status scheduled
    @message = @conversation.messages.build(message_params)
    @message.account = Current.account
    @message.inbox = @conversation.inbox
    @message.sender = Current.user
    @message.message_type = :outgoing

    # Define as agendada
    @message.schedule_for(Time.parse(params[:scheduled_at]))

    if @message.save
      render json: {
        message: @message.as_json,
        scheduled_at: @message.scheduled_at,
        display_at: @message.display_timestamp
      }
    else
      render json: { errors: @message.errors }, status: :unprocessable_entity
    end
  end
  
  def index
    # List scheduled messages for the conversation
    @scheduled_messages = @conversation.messages.scheduled
                                      .includes(:sender, :attachments)
                                      .order(created_at: :desc)
    render json: @scheduled_messages.map { |msg|
      msg.as_json.merge(
        scheduled_at: msg.scheduled_at,
        display_at: msg.display_timestamp
      )
    }
  end
  
  def destroy
    # Cancel scheduled message
    @message = @conversation.messages.scheduled.find(params[:id])
    @message.update!(status: :failed) # Mark as cancelled
    head :no_content
  end
  
  private
  

  
  def message_params
    params.require(:message).permit(:content, :private, content_attributes: {})
  end
end
