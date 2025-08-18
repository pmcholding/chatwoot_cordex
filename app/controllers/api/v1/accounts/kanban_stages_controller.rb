class Api::V1::Accounts::KanbanStagesController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_stage, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @kanban_stages = Current.account.kanban_stages.ordered.includes(:conversations)

    # Include conversation counts if requested
    return unless params[:include_counts] == 'true'

    @kanban_stages = @kanban_stages.map do |stage|
      stage.as_json.merge(conversations_count: stage.conversations_count)
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
    positions = params.require(:positions)

    return render json: { error: 'Invalid payload: positions must be an array' }, status: :unprocessable_entity unless positions.is_a?(Array)

    # Normalize and validate payload
    id_to_target_position = positions.each_with_object({}) do |pos_data, memo|
      data = pos_data.respond_to?(:to_unsafe_h) ? pos_data.to_unsafe_h : pos_data
      id = (data[:id] || data['id']).to_i
      target = (data[:position] || data['position']).to_i
      memo[id] = target
    end

    ids = id_to_target_position.keys
    return render json: { error: 'No positions provided' }, status: :unprocessable_entity if ids.empty?

    # Validate target positions range
    unless id_to_target_position.values.all? { |p| p.is_a?(Integer) && p >= 1 && p <= 20 }
      return render json: { error: 'Positions must be integers between 1 and 20' }, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      stages = Current.account.kanban_stages.where(id: ids).select(:id, :position).to_a
      found_ids = stages.map(&:id)
      missing = ids - found_ids
      raise ActiveRecord::RecordNotFound, 'One or more stages not found' if missing.any?

      # Build quick lookup maps
      id_to_current_position = stages.index_by(&:id).transform_values(&:position)
      position_to_id = id_to_current_position.invert

      # Choose a temporary free position within allowed range (1..20)
      used_positions = Current.account.kanban_stages.pluck(:position)
      free_positions = ((1..20).to_a - used_positions)
      temp_position = free_positions.first

      if temp_position.nil?
        # No free position available to use as a buffer; for simplicity, abort gracefully
        # This can happen only if there are already 20 stages
        raise StandardError, 'No free position available to reorder (max stages reached)'
      end

      # Process in increasing target position order for determinism
      ids_sorted = ids.sort_by { |id| id_to_target_position[id] }

      ids_sorted.each do |id|
        desired = id_to_target_position[id]
        current = id_to_current_position[id]
        next if desired == current

        occupant_id = position_to_id[desired]

        if occupant_id && occupant_id != id
          # Move the occupant to a temporary free slot first
          Current.account.kanban_stages.where(id: occupant_id).update_all(position: temp_position)
          # Update maps
          position_to_id.delete(desired)
          position_to_id[temp_position] = occupant_id
          id_to_current_position[occupant_id] = temp_position
        end

        # Now move the desired stage to its target position
        Current.account.kanban_stages.where(id: id).update_all(position: desired)
        position_to_id.delete(current)
        position_to_id[desired] = id
        id_to_current_position[id] = desired

        # The previous position of the moved stage becomes the new temporary free slot
        temp_position = current
      end
    end

    render json: { message: 'Stages reordered successfully' }
  rescue ActiveRecord::RecordNotFound
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
    rescue StandardError => e
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
          contact_avatar: conversation.contact.avatar_url,
          assignee: if conversation.assignee
                      {
                        id: conversation.assignee.id,
                        name: conversation.assignee.name,
                        avatar_url: conversation.assignee.avatar_url
                      }
                    end,
          inbox: {
            id: conversation.inbox.id,
            name: conversation.inbox.name,
            channel_type: conversation.inbox.channel_type
          },
          status: conversation.status,
          priority: conversation.priority,
          labels: Current.account.labels.where(title: conversation.cached_label_list_array).map do |label|
            {
              id: label.id,
              title: label.title,
              color: label.color
            }
          end,
          unread_count: conversation.unread_incoming_messages.count,
          updated_at: conversation.updated_at,
          last_activity_at: conversation.last_activity_at,
          kanban_stage_id: conversation.kanban_stage_id
        }
      end
    end
  end
end
