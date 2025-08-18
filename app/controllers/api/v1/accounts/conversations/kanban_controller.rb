class Api::V1::Accounts::Conversations::KanbanController < Api::V1::Accounts::Conversations::BaseController
  before_action :set_conversation, only: [:move]

  # Move conversation to a different kanban stage
  def move
    stage_id = params[:kanban_stage_id]

    if stage_id.present?
      stage = Current.account.kanban_stages.find(stage_id)
      @conversation.move_to_kanban_stage!(stage)
    else
      # Move to unassigned (remove from any stage)
      @conversation.update!(kanban_stage: nil)
    end

    render json: {
      id: @conversation.display_id,
      display_id: @conversation.display_id,
      kanban_stage_id: @conversation.kanban_stage_id,
      kanban_stage_name: @conversation.kanban_stage_name,
      message: 'Conversation moved successfully'
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Kanban stage not found' }, status: :not_found
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # Bulk move conversations
  def bulk_move
    conversation_ids = params[:conversation_ids]
    stage_id = params[:kanban_stage_id]

    conversations = Current.account.conversations.where(display_id: conversation_ids)

    if stage_id.present?
      stage = Current.account.kanban_stages.find(stage_id)
      conversations.update_all(kanban_stage_id: stage.id)
    else
      conversations.update_all(kanban_stage_id: nil)
    end

    render json: {
      moved_count: conversations.count,
      message: "#{conversations.count} conversations moved successfully"
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Kanban stage not found' }, status: :not_found
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_conversation
    @conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    authorize @conversation.inbox, :show?
  end
end
