class Api::V1::Accounts::AgentTemplatesController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    @agent_templates = agent_templates
  end

  private

  def check_authorization
    super(User)
  end

  def agent_templates
    @agent_templates ||= AgentTemplate.available_for(Current.account).order(:name)
  end
end
