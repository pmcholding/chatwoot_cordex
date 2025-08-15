import { describe, it, beforeEach, expect, vi } from 'vitest';

// Mock the API
vi.mock('dashboard/api/captain/assistant', () => ({
  default: {
    generateInstructions: vi.fn(),
  },
}));

// Mock useAlert
vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

// Mock i18n
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

import { useInstructionGenerator } from './useInstructionGenerator';
import CaptainAssistant from 'dashboard/api/captain/assistant';
import { useAlert } from 'dashboard/composables';

describe('useInstructionGenerator', () => {
  let composable;

  beforeEach(() => {
    vi.clearAllMocks();
    composable = useInstructionGenerator();
  });

  describe('isFinalPromptReady', () => {
    it('should return true when response contains [FINAL_PROMPT_READY] marker', () => {
      const responseWithMarker = `
**Instructions:**

**Role and Purpose:**
You are a helpful assistant.

[FINAL_PROMPT_READY]

Pronto! Criei as instruções completas.
      `;

      expect(composable.isFinalPromptReady(responseWithMarker)).toBe(true);
    });

    it('should return false when response does not contain [FINAL_PROMPT_READY] marker', () => {
      const responseWithoutMarker = `
**Instructions:**

**Role and Purpose:**
You are a helpful assistant.
      `;

      expect(composable.isFinalPromptReady(responseWithoutMarker)).toBe(false);
    });

    it('should handle empty or null responses', () => {
      expect(composable.isFinalPromptReady('')).toBe(false);
      expect(composable.isFinalPromptReady(null)).toBe(false);
      expect(composable.isFinalPromptReady(undefined)).toBe(false);
    });
  });

  describe('extractInstructions', () => {
    it('should extract instructions before [FINAL_PROMPT_READY] marker', () => {
      const responseWithMarker = `**Instructions:**

**Role and Purpose:**
You are a helpful customer support agent.

**Key Responsibilities:**
- Answer customer questions
- Provide accurate information

[FINAL_PROMPT_READY]

Pronto! Criei as instruções completas para seu assistente.`;

      const expected = `**Instructions:**

**Role and Purpose:**
You are a helpful customer support agent.

**Key Responsibilities:**
- Answer customer questions
- Provide accurate information`;

      expect(composable.extractInstructions(responseWithMarker)).toBe(expected);
    });

    it('should return full response if no marker present', () => {
      const responseWithoutMarker = `**Instructions:**

**Role and Purpose:**
You are a helpful assistant.`;

      expect(composable.extractInstructions(responseWithoutMarker)).toBe(
        responseWithoutMarker
      );
    });

    it('should handle responses with multiple markers (take first part)', () => {
      const responseWithMultipleMarkers = `**Instructions:**

Content before first marker

[FINAL_PROMPT_READY]

Content between markers

[FINAL_PROMPT_READY]

Content after second marker`;

      const expected = `**Instructions:**

Content before first marker`;

      expect(composable.extractInstructions(responseWithMultipleMarkers)).toBe(
        expected
      );
    });

    it('should trim whitespace from extracted instructions', () => {
      const responseWithWhitespace = `   

**Instructions:**

**Role and Purpose:**
You are a helpful assistant.

   

[FINAL_PROMPT_READY]

Confirmation text`;

      const expected = `**Instructions:**

**Role and Purpose:**
You are a helpful assistant.`;

      expect(composable.extractInstructions(responseWithWhitespace)).toBe(
        expected
      );
    });
  });

  describe('generateInstructions integration', () => {
    it('should handle successful API response with [FINAL_PROMPT_READY] marker', async () => {
      const mockResponse = {
        data: {
          message: `**Instructions:**

**Role and Purpose:**
You are a helpful assistant.

[FINAL_PROMPT_READY]

Pronto! Criei as instruções.`,
        },
      };

      CaptainAssistant.generateInstructions.mockResolvedValue(mockResponse);

      const result = await composable.generateInstructions(
        'Create instructions'
      );

      expect(result).toBe(mockResponse.data.message);
      expect(composable.conversationHistory.value).toHaveLength(2); // user + assistant
      expect(composable.conversationHistory.value[0].role).toBe('user');
      expect(composable.conversationHistory.value[1].role).toBe('assistant');
    });

    it('should handle API errors gracefully', async () => {
      const mockError = new Error('API Error');
      mockError.response = {
        data: {
          error: {
            message: 'Custom error message',
          },
        },
      };

      CaptainAssistant.generateInstructions.mockRejectedValue(mockError);

      await expect(
        composable.generateInstructions('Test input')
      ).rejects.toThrow('API Error');
      expect(useAlert).toHaveBeenCalledWith('Custom error message');
      expect(composable.error.value).toBe('Custom error message');
    });
  });

  describe('conversation history management', () => {
    it('should add messages to conversation history', () => {
      composable.addMessage('user', 'Hello');
      composable.addMessage('assistant', 'Hi there!');

      expect(composable.conversationHistory.value).toHaveLength(2);
      expect(composable.conversationHistory.value[0]).toMatchObject({
        role: 'user',
        content: 'Hello',
      });
      expect(composable.conversationHistory.value[1]).toMatchObject({
        role: 'assistant',
        content: 'Hi there!',
      });
    });

    it('should reset conversation history', () => {
      composable.addMessage('user', 'Hello');
      composable.addMessage('assistant', 'Hi there!');

      composable.resetConversation();

      expect(composable.conversationHistory.value).toHaveLength(0);
      expect(composable.error.value).toBe('');
      expect(composable.isGenerating.value).toBe(false);
    });
  });

  describe('backward compatibility', () => {
    it('should maintain existing isInstructionResponse functionality', () => {
      const instructionResponse = `**Instructions:**

**Role and Purpose:**
You are a helpful assistant.

**Key Responsibilities:**
- Task 1
- Task 2

**Behavioral Guidelines:**
- Guideline 1
- Guideline 2

**Communication Style:**
Professional and friendly`;

      expect(composable.isInstructionResponse(instructionResponse)).toBe(true);
    });

    it('should not identify incomplete instruction responses', () => {
      const incompleteResponse = `**Instructions:**

**Role and Purpose:**
You are a helpful assistant.

**Key Responsibilities:**
- Task 1`;

      expect(composable.isInstructionResponse(incompleteResponse)).toBe(false);
    });
  });
});
