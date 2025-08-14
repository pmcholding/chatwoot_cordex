class Captain::Llm::InstructionGeneratorService < Llm::BaseOpenAiService
  def initialize(conversation_history = [], user_input = '')
    super()
    @conversation_history = conversation_history || []
    @user_input = user_input
  end

  def generate
    response = @client.chat(parameters: chat_parameters)
    parse_response(response)
  rescue OpenAI::Error => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    { message: 'Sorry, I encountered an error while generating instructions. Please try again.' }
  end

  private

  attr_reader :conversation_history, :user_input

  def chat_parameters
    {
      model: @model,
      messages: build_messages
    }
  end

  def build_messages
    messages = [
      {
        role: 'system',
        content: Captain::Llm::SystemPromptsService.instruction_generator
      }
    ]

    # Add conversation history if present
    conversation_history.each do |message|
      messages << {
        role: message['role'],
        content: message['content']
      }
    end

    # Add current user input
    messages << {
      role: 'user',
      content: user_input
    }

    messages
  end

  def parse_response(response)
    choices = response['choices']
    return { message: 'No response generated' } unless choices&.any?

    content = choices.first.dig('message', 'content')
    { message: content || 'No instructions generated' }
  end
end
