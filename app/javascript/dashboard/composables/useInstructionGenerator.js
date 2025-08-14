import { ref, computed, readonly } from 'vue';
import { useI18n } from 'vue-i18n';
import CaptainAssistant from 'dashboard/api/captain/assistant';
import { useAlert } from 'dashboard/composables';

/**
 * Composable for AI instruction generation functionality
 * @returns {Object} Instruction generation utilities and state
 */
export function useInstructionGenerator() {
  const { t } = useI18n();

  // State
  const isGenerating = ref(false);
  const conversationHistory = ref([]);
  const error = ref('');

  // For Captain AI, we don't need to check regular integrations
  // The backend will handle the CAPTAIN_OPEN_AI_API_KEY configuration
  const isAIIntegrationEnabled = computed(() => true);

  // Computed
  const canGenerate = computed(() => !isGenerating.value);

  // Captain AI doesn't need hookId - it uses direct API endpoint

  /**
   * Adds a message to the conversation history
   * @param {string} role - The role of the message sender ('user' or 'assistant')
   * @param {string} content - The message content
   */
  const addMessage = (role, content) => {
    conversationHistory.value.push({
      role,
      content,
      timestamp: Date.now(),
    });
  };

  /**
   * Generates AI instructions based on user input and conversation history
   * @param {string} userInput - The user's input message
   * @returns {Promise<string>} The generated response from the AI
   */
  const generateInstructions = async userInput => {
    if (!canGenerate.value) {
      const errorMsg = t(
        'INTEGRATIONS.INSTRUCTION_GENERATOR.ERROR.GENERATION_FAILED'
      );
      useAlert(errorMsg);
      throw new Error(errorMsg);
    }

    try {
      isGenerating.value = true;
      error.value = '';

      // Add user message to history
      addMessage('user', userInput);

      // Prepare conversation history for API (exclude the current message)
      const historyForAPI = conversationHistory.value.slice(0, -1).map(msg => ({
        role: msg.role,
        content: msg.content,
      }));

      // Call the Captain instruction generation API
      const response = await CaptainAssistant.generateInstructions({
        conversationHistory: historyForAPI,
        userInput: userInput,
      });

      const assistantResponse = response.data.message;

      // Add assistant response to history
      addMessage('assistant', assistantResponse);

      return assistantResponse;
    } catch (err) {
      error.value =
        err.response?.data?.error?.message ||
        t('INTEGRATIONS.INSTRUCTION_GENERATOR.ERROR.GENERATION_FAILED');

      useAlert(error.value);
      throw err;
    } finally {
      isGenerating.value = false;
    }
  };

  /**
   * Resets the conversation history and state
   */
  const resetConversation = () => {
    conversationHistory.value = [];
    error.value = '';
    isGenerating.value = false;
  };

  /**
   * Checks if the response contains final instructions
   * @param {string} response - The AI response to check
   * @returns {boolean} True if the response appears to be final instructions
   */
  const isInstructionResponse = response => {
    const instructionKeywords = [
      '**Instructions:**',
      'Instructions:',
      '**Role and Purpose:**',
      'Role and Purpose:',
      '**Key Responsibilities:**',
      'Key Responsibilities:',
      '**Behavioral Guidelines:**',
      'Behavioral Guidelines:',
      '**Communication Style:**',
      'Communication Style:',
      '**Limitations and Boundaries:**',
      'Limitations and Boundaries:',
    ];

    // Check if response contains multiple instruction sections (indicates final instructions)
    const keywordCount = instructionKeywords.filter(keyword =>
      response.includes(keyword)
    ).length;

    return keywordCount >= 3; // Must have at least 3 sections to be considered final instructions
  };

  /**
   * Initializes conversation with context
   * @param {Object} context - Initial context for the conversation
   * @param {string} context.agentName - Name of the agent
   * @param {string} context.existingInstructions - Existing instructions to improve
   * @param {string} context.agentType - Type of agent to create
   */
  const initializeWithContext = (context = {}) => {
    resetConversation();

    let contextMessage = t(
      'INTEGRATIONS.INSTRUCTION_GENERATOR.INITIAL_CONTEXT'
    );

    if (context.agentName) {
      contextMessage += ` ${t('INTEGRATIONS.INSTRUCTION_GENERATOR.AGENT_NAME')}: ${context.agentName}.`;
    }

    if (context.agentType) {
      contextMessage += ` I want to create a ${context.agentType} agent.`;
    }

    if (context.existingInstructions) {
      contextMessage += ` ${t('INTEGRATIONS.INSTRUCTION_GENERATOR.EXISTING_INSTRUCTIONS')}: ${context.existingInstructions}`;
    }

    return contextMessage;
  };

  return {
    // State
    isGenerating: readonly(isGenerating),
    conversationHistory: readonly(conversationHistory),
    error: readonly(error),

    // Computed
    canGenerate,
    isAIIntegrationEnabled,

    // Methods
    generateInstructions,
    resetConversation,
    addMessage,
    isInstructionResponse,
    initializeWithContext,
  };
}

export default useInstructionGenerator;
