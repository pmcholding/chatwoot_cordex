class Api::V1::Accounts::Captain::AssistantsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Captain::Assistant) }

  before_action :set_assistant, only: [:show, :update, :destroy, :playground]

  def index
    @assistants = account_assistants.ordered
  end

  def show; end

  def create
    @assistant = account_assistants.create!(assistant_params)
  end

  def update
    @assistant.update!(assistant_params)
  end

  def destroy
    @assistant.destroy
    head :no_content
  end

  def playground
    response = Captain::Llm::AssistantChatService.new(assistant: @assistant).generate_response(
      additional_message: params[:message_content],
      message_history: message_history
    )

    render json: response
  end

  def generate_instructions
    conversation_history = params[:conversation_history] || []
    user_input = params[:user_input] || ''

    service = Captain::Llm::InstructionGeneratorService.new(conversation_history, user_input)
    response = service.generate

    render json: response
  rescue StandardError => e
    Rails.logger.error "Instruction generation error: #{e.message}"
    render json: {
      message: 'Sorry, I encountered an error while generating instructions. Please try again.'
    }, status: :unprocessable_entity
  end

  def tools
    @tools = Captain::Assistant.available_agent_tools
  end

  private

  def set_assistant
    @assistant = account_assistants.find(params[:id])
  end

  def account_assistants
    @account_assistants ||= Captain::Assistant.for_account(Current.account.id)
  end

  def assistant_params
    permitted = params.require(:assistant).permit(:name, :description,
                                                  config: [
                                                    :product_name, :feature_faq, :feature_memory, :feature_citation,
                                                    :welcome_message, :handoff_message, :resolution_message,
                                                    :instructions, :temperature
                                                  ])

    # Handle array parameters separately to allow partial updates
    permitted[:response_guidelines] = params[:assistant][:response_guidelines] if params[:assistant].key?(:response_guidelines)

    permitted[:guardrails] = params[:assistant][:guardrails] if params[:assistant].key?(:guardrails)

    permitted
  end

  def playground_params
    params.require(:assistant).permit(:message_content, message_history: [:role, :content])
  end

  def message_history
    (playground_params[:message_history] || []).map { |message| { role: message[:role], content: message[:content] } }
  end
end
