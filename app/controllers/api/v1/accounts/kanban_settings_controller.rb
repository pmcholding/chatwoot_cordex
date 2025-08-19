class Api::V1::Accounts::KanbanSettingsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :set_kanban_setting

  def show
    render json: serialize(@kanban_setting)
  end

  def update
    if @kanban_setting.update(kanban_settings_params)
      render json: serialize(@kanban_setting)
    else
      render json: { errors: @kanban_setting.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_kanban_setting
    @kanban_setting = KanbanSetting.find_by(account: Current.account)
    return if @kanban_setting

    @kanban_setting = KanbanSetting.new(
      account: Current.account,
      auto_assign_conversations: false,
      show_conversation_count: true,
      default_filters: {}
    )
    @kanban_setting.save(validate: false) unless @kanban_setting.persisted?
  end

  def kanban_settings_params
    params.permit(
      :auto_assign_conversations,
      :show_conversation_count,
      :default_stage_id,
      default_filters: [:inboxId, :assigneeId, { labelIds: [] }]
    )
  end

  def serialize(rec)
    {
      auto_assign_conversations: rec.auto_assign_conversations,
      show_conversation_count: rec.show_conversation_count,
      default_stage_id: rec.default_stage_id,
      default_filters: rec.default_filters
    }
  end
end
