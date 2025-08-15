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
    # Use the language parameter, account locale, or default to 'en'
    language = params[:language] || account_locale || 'en'
    @agent_templates ||= AgentTemplate.for_language(language).by_name
  end

  def account_locale
    # Convert account locale format (pt_BR) to template format (pt-BR)
    locale = Current.account&.locale
    return nil unless locale

    # Convert underscore to hyphen for consistency with template language format
    locale.tr('_', '-')
  end
end
