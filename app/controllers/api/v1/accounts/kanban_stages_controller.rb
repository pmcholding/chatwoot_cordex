class Api::V1::Accounts::KanbanStagesController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_stage, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @kanban_stages = Current.account.kanban_stages.ordered.includes(:conversations)
    
    # Include conversation counts if requested
    if params[:include_counts] == 'true'
      @kanban_stages = @kanban_stages.map do |stage|
        stage.as_json.merge(conversations_count: stage.conversations_count)
      end
    end
  end

  def show
    render json: @kanban_stage.as_json(include: { conversations: { only: [:id, :display_id] } })
  end

  def create
    @kanban_stage = Current.account.kanban_stages.new(kanban_stage_params)
    
    if @kanban_stage.save
      render json: @kanban_stage, status: :created
    else
      render json: { errors: @kanban_stage.errors }, status: :unprocessable_entity
    end
  end

  def update
    if @kanban_stage.update(kanban_stage_params)
      render json: @kanban_stage
    else
      render json: { errors: @kanban_stage.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    @kanban_stage.destroy!
    head :ok
  end

  # Custom action to reorder stages
  def reorder
    positions = params[:positions] # Expected: [{ id: 1, position: 1 }, { id: 2, position: 2 }]
    
    ActiveRecord::Base.transaction do
      positions.each do |pos_data|
        stage = Current.account.kanban_stages.find(pos_data[:id])
        stage.update!(position: pos_data[:position])
      end
    end

    render json: { message: 'Stages reordered successfully' }
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: 'Stage not found' }, status: :not_found
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # Get kanban board data with conversations
  def board_data
    filters = params.permit(:q, :assignee_id, :inbox_id, :status, label_ids: [], created_after: nil, created_before: nil)

    begin
      data = Conversation.kanban_board_data(Current.account, filters)

      render json: {
        stages: data[:stages].as_json,
        conversations_by_stage: serialize_conversations_by_stage(data[:conversations_by_stage]),
        total_count: data[:total_count]
      }
    rescue => e
      render json: { error: e.message, backtrace: e.backtrace.first(5) }, status: :internal_server_error
    end
  end

  private

  def fetch_kanban_stage
    @kanban_stage = Current.account.kanban_stages.find(params[:id])
  end

  def kanban_stage_params
    params.require(:kanban_stage).permit(:name, :color, :position)
  end

  def serialize_conversations_by_stage(conversations_by_stage)
    conversations_by_stage.transform_values do |conversations|
      conversations.map do |conversation|
        last_message = conversation.messages.order(:created_at).last

        {
          id: conversation.id,
          display_id: conversation.display_id,
          title: last_message&.content || "Conversation ##{conversation.display_id}",
          subject: last_message&.content,
          last_message: last_message&.content,
          contact_name: conversation.contact.name,
          contact_phone: conversation.contact.phone_number,
          contact_email: conversation.contact.email,
          assignee: conversation.assignee ? {
            id: conversation.assignee.id,
            name: conversation.assignee.name,
            avatar_url: conversation.assignee.avatar_url
          } : nil,
          inbox: {
            id: conversation.inbox.id,
            name: conversation.inbox.name,
            channel_type: conversation.inbox.channel_type
          },
          status: conversation.status,
          priority: conversation.priority,
          labels: conversation.labels.map { |label| {
            id: label.id,
            title: label.title,
            color: label.color
          }},
          unread_count: conversation.unread_incoming_messages.count,
          updated_at: conversation.updated_at,
          last_activity_at: conversation.last_activity_at,
          kanban_stage_id: conversation.kanban_stage_id
        }
      end
    end
  end
end
