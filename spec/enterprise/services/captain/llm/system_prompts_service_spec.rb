require 'rails_helper'

RSpec.describe Captain::Llm::SystemPromptsService do
  describe '.instruction_generator' do
    context 'when CAPTAIN_INSTRUCTION_GENERATOR_PROMPT is configured' do
      let(:custom_prompt) { 'Custom instruction generator prompt for testing' }

      before do
        allow(GlobalConfig).to receive(:get_value)
          .with('CAPTAIN_INSTRUCTION_GENERATOR_PROMPT')
          .and_return(custom_prompt)
      end

      it 'returns the configured prompt' do
        expect(described_class.instruction_generator).to eq(custom_prompt)
      end
    end

    context 'when CAPTAIN_INSTRUCTION_GENERATOR_PROMPT is not configured' do
      before do
        allow(GlobalConfig).to receive(:get_value)
          .with('CAPTAIN_INSTRUCTION_GENERATOR_PROMPT')
          .and_return(nil)
      end

      it 'returns the default prompt' do
        result = described_class.instruction_generator

        expect(result).to include('You are an AI assistant specialized in creating comprehensive agent instructions')
        expect(result).to include('Guidelines:')
        expect(result).to include('Output Format:')
        expect(result).to include('Conversation Flow:')
        expect(result).to include('Begin by asking the user what kind of agent they want to create')
      end

      it 'includes all required sections in the default prompt' do
        result = described_class.instruction_generator

        expect(result).to include('agent role and purpose')
        expect(result).to include('key responsibilities')
        expect(result).to include('behavioral guidelines')
        expect(result).to include('response patterns')
        expect(result).to include('escalation procedures')
      end
    end
  end

  describe '.faq_generator' do
    it 'returns the FAQ generator prompt' do
      result = described_class.faq_generator

      expect(result).to include('You are a content writer looking to convert user content into short FAQs')
      expect(result).to include('JSON format')
    end
  end

  describe '.conversation_faq_generator' do
    it 'returns the conversation FAQ generator prompt with default language' do
      result = described_class.conversation_faq_generator

      expect(result).to include('You are a support agent looking to convert the conversations')
      expect(result).to include('english')
    end

    it 'returns the conversation FAQ generator prompt with custom language' do
      result = described_class.conversation_faq_generator('portuguese')

      expect(result).to include('portuguese')
    end
  end
end
