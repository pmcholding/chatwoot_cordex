import { describe, it, beforeEach, expect, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import InstructionGeneratorModal from './InstructionGeneratorModal.vue';

// Mock the composable
const mockGenerateInstructions = vi.fn();
const mockResetConversation = vi.fn();
const mockIsFinalPromptReady = vi.fn();
const mockExtractInstructions = vi.fn();
const mockIsInstructionResponse = vi.fn();
const mockInitializeWithContext = vi.fn();

vi.mock('dashboard/composables/useInstructionGenerator', () => ({
  useInstructionGenerator: () => ({
    isGenerating: { value: false },
    conversationHistory: { value: [] },
    error: { value: '' },
    canGenerate: { value: true },
    generateInstructions: mockGenerateInstructions,
    resetConversation: mockResetConversation,
    isInstructionResponse: mockIsInstructionResponse,
    isFinalPromptReady: mockIsFinalPromptReady,
    extractInstructions: mockExtractInstructions,
    initializeWithContext: mockInitializeWithContext,
  }),
}));

// Mock the API
vi.mock('dashboard/api/captain/assistant', () => ({
  default: {
    generateInstructions: vi.fn(),
  },
}));

describe('InstructionGeneratorModal', () => {
  let wrapper;

  const defaultProps = {
    show: true,
    initialContext: {
      agentName: 'Test Agent',
      existingInstructions: 'Existing instructions',
    },
  };

  beforeEach(() => {
    vi.clearAllMocks();
    wrapper = mount(InstructionGeneratorModal, {
      props: defaultProps,
    });
  });

  afterEach(() => {
    wrapper.unmount();
  });

  describe('Final Prompt Ready Detection', () => {
    it('should detect [FINAL_PROMPT_READY] marker and show confirmation buttons', async () => {
      const responseWithMarker = `
**Instructions:**

**Role and Purpose:**
You are a helpful customer support agent.

**Key Responsibilities:**
- Answer customer questions
- Provide accurate information
- Escalate complex issues

[FINAL_PROMPT_READY]

Pronto! Criei as instruções completas para seu assistente.
      `;

      mockIsFinalPromptReady.mockReturnValue(true);
      mockExtractInstructions.mockReturnValue(
        '**Instructions:**\n\n**Role and Purpose:**\nYou are a helpful customer support agent.'
      );
      mockGenerateInstructions.mockResolvedValue(responseWithMarker);

      // Set input value and call sendMessage directly
      wrapper.vm.currentInput = 'Create instructions for a support agent';
      await wrapper.vm.sendMessage();

      await nextTick();

      // Should show confirmation buttons
      expect(wrapper.vm.showConfirmationButtons).toBe(true);
      expect(wrapper.find('[data-testid="accept-button"]').exists()).toBe(true);
      expect(wrapper.find('[data-testid="edit-button"]').exists()).toBe(true);
    });

    it('should extract instructions without marker and confirmation text', async () => {
      const responseWithMarker = `
**Instructions:**

**Role and Purpose:**
You are a helpful customer support agent.

[FINAL_PROMPT_READY]

Pronto! Criei as instruções completas para seu assistente.
      `;

      mockIsFinalPromptReady.mockReturnValue(true);
      mockExtractInstructions.mockReturnValue(
        '**Instructions:**\n\n**Role and Purpose:**\nYou are a helpful customer support agent.'
      );
      mockGenerateInstructions.mockResolvedValue(responseWithMarker);

      wrapper.vm.currentInput = 'Test input';
      await wrapper.vm.sendMessage();

      expect(mockExtractInstructions).toHaveBeenCalledWith(responseWithMarker);
      expect(wrapper.vm.generatedInstructions).toBe(
        '**Instructions:**\n\n**Role and Purpose:**\nYou are a helpful customer support agent.'
      );
    });
  });

  describe('Confirmation Buttons Actions', () => {
    beforeEach(async () => {
      // Setup state with confirmation buttons visible
      wrapper.vm.showConfirmationButtons = true;
      wrapper.vm.generatedInstructions = 'Test instructions';
      await nextTick();
    });

    it('should apply instructions when accept button is clicked', async () => {
      const acceptButton = wrapper.find('[data-testid="accept-button"]');
      await acceptButton.trigger('click');

      expect(wrapper.emitted('applyInstructions')).toBeTruthy();
      expect(wrapper.emitted('applyInstructions')[0]).toEqual([
        'Test instructions',
      ]);
      expect(wrapper.emitted('close')).toBeTruthy();
    });

    it('should enter edit mode when edit button is clicked', async () => {
      const editButton = wrapper.find('[data-testid="edit-button"]');
      await editButton.trigger('click');

      expect(wrapper.vm.showConfirmationButtons).toBe(false);
      expect(wrapper.vm.isApplyingInstructions).toBe(false);
      expect(wrapper.vm.currentInput).toContain(
        'Gostaria de fazer algumas modificações'
      );
    });
  });

  describe('Backward Compatibility', () => {
    it('should fallback to old behavior when no [FINAL_PROMPT_READY] marker', async () => {
      const responseWithoutMarker = `
**Instructions:**

**Role and Purpose:**
You are a helpful customer support agent.

**Key Responsibilities:**
- Answer customer questions
      `;

      mockIsFinalPromptReady.mockReturnValue(false);
      mockIsInstructionResponse.mockReturnValue(true);
      mockGenerateInstructions.mockResolvedValue(responseWithoutMarker);

      wrapper.vm.currentInput = 'Test input';
      await wrapper.vm.sendMessage();

      expect(wrapper.vm.showConfirmationButtons).toBe(false);
      expect(wrapper.vm.isApplyingInstructions).toBe(true);
    });
  });

  describe('Reset Functionality', () => {
    it('should reset confirmation buttons state when conversation is reset', async () => {
      wrapper.vm.showConfirmationButtons = true;

      await wrapper.vm.resetConversation();

      expect(wrapper.vm.showConfirmationButtons).toBe(false);
      expect(wrapper.vm.generatedInstructions).toBe('');
      expect(wrapper.vm.isApplyingInstructions).toBe(false);
    });
  });

  describe('UI State Management', () => {
    it('should hide input area when confirmation buttons are shown', async () => {
      wrapper.vm.showConfirmationButtons = true;
      await nextTick();

      const inputArea = wrapper.find('[data-testid="input-area"]');
      expect(inputArea.exists()).toBe(false);
    });

    it('should show input area when confirmation buttons are hidden', async () => {
      wrapper.vm.showConfirmationButtons = false;
      wrapper.vm.isApplyingInstructions = false;
      await nextTick();

      const inputArea = wrapper.find('[data-testid="input-area"]');
      expect(inputArea.exists()).toBe(true);
    });

    it('should display generated instructions in confirmation section', async () => {
      const testInstructions = 'Test generated instructions';
      wrapper.vm.showConfirmationButtons = true;
      wrapper.vm.generatedInstructions = testInstructions;
      await nextTick();

      const instructionsDisplay = wrapper.find(
        '[data-testid="generated-instructions"]'
      );
      expect(instructionsDisplay.text()).toContain(testInstructions);
    });
  });
});
