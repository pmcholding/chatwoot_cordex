require 'rails_helper'

RSpec.describe Captain::Llm::InstructionGeneratorService do
  let(:service) { described_class.new(conversation_history, user_input) }
  let(:conversation_history) { [] }
  let(:user_input) { 'I want to create a customer support agent' }
  let(:mock_client) { instance_double(OpenAI::Client) }
  let(:mock_response) do
    {
      'choices' => [
        {
          'message' => {
            'content' => 'Generated agent instructions for customer support'
          }
        }
      ]
    }
  end

  before do
    # Mock the InstallationConfig dependencies
    allow(InstallationConfig).to receive(:find_by!).with(name: 'CAPTAIN_OPEN_AI_API_KEY')
                                                   .and_return(double(value: 'test-api-key'))
    allow(InstallationConfig).to receive(:find_by).with(name: 'CAPTAIN_OPEN_AI_MODEL')
                                                  .and_return(double(value: 'gpt-4o-mini'))
    allow(InstallationConfig).to receive(:find_by).with(name: 'CAPTAIN_INSTRUCTION_GENERATOR_PROMPT')
                                                  .and_return(nil)

    # Mock GlobalConfig for the instruction generator prompt
    allow(GlobalConfig).to receive(:get_value).with('CAPTAIN_INSTRUCTION_GENERATOR_PROMPT')
                                              .and_return(nil)

    # Mock the OpenAI client
    allow(OpenAI::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:chat).and_return(mock_response)
  end

  describe '#generate' do
    context 'with successful OpenAI response' do
      it 'returns generated instructions' do
        result = service.generate

        expect(result[:message]).to eq('Generated agent instructions for customer support')
      end

      it 'calls OpenAI with correct parameters' do
        expect(mock_client).to receive(:chat).with(
          parameters: hash_including(
            model: anything,
            messages: array_including(
              hash_including(role: 'system'),
              hash_including(role: 'user', content: user_input)
            )
          )
        )

        service.generate
      end
    end

    context 'with conversation history' do
      let(:conversation_history) do
        [
          { 'role' => 'user', 'content' => 'I need help creating an agent' },
          { 'role' => 'assistant', 'content' => 'What type of agent do you want to create?' }
        ]
      end

      it 'includes conversation history in messages' do
        expect(mock_client).to receive(:chat).with(
          parameters: hash_including(
            messages: array_including(
              hash_including(role: 'system'),
              hash_including(role: 'user', content: 'I need help creating an agent'),
              hash_including(role: 'assistant', content: 'What type of agent do you want to create?'),
              hash_including(role: 'user', content: user_input)
            )
          )
        )

        service.generate
      end
    end

    context 'when OpenAI API returns error' do
      before do
        allow(mock_client).to receive(:chat).and_raise(OpenAI::Error.new('API Error'))
      end

      it 'returns error message' do
        result = service.generate

        expect(result[:message]).to include('Sorry, I encountered an error')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/OpenAI API Error/)

        service.generate
      end
    end

    context 'when OpenAI response has no choices' do
      let(:mock_response) { { 'choices' => [] } }

      it 'returns no response message' do
        result = service.generate

        expect(result[:message]).to eq('No response generated')
      end
    end

    context 'when OpenAI response has no content' do
      let(:mock_response) do
        {
          'choices' => [
            {
              'message' => {
                'content' => nil
              }
            }
          ]
        }
      end

      it 'returns no instructions message' do
        result = service.generate

        expect(result[:message]).to eq('No instructions generated')
      end
    end
  end
end
