<script>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useInstructionGenerator } from 'dashboard/composables/useInstructionGenerator';
import Modal from 'dashboard/components/Modal.vue';
import WootButton from 'dashboard/components-next/button/Button.vue';
import AILoader from './AILoader.vue';

export default {
  name: 'InstructionGeneratorModal',
  components: {
    Modal,
    WootButton,
    AILoader,
  },
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    initialContext: {
      type: Object,
      default: () => ({}),
    },
  },
  emits: ['close', 'applyInstructions'],
  setup(props, { emit }) {
    const { t } = useI18n();
    const {
      isGenerating,
      conversationHistory,
      error,
      canGenerate,
      generateInstructions,
      resetConversation: resetInstructionConversation,
      isInstructionResponse,
      isFinalPromptReady,
      extractInstructions,
      initializeWithContext,
    } = useInstructionGenerator();

    // Local state
    const currentInput = ref('');
    const generatedInstructions = ref('');
    const isApplyingInstructions = ref(false);
    const showConfirmationButtons = ref(false);

    // Computed
    const hasMessages = computed(() => conversationHistory.value.length > 0);
    const canSendMessage = computed(() => {
      return currentInput.value.trim().length > 0 && canGenerate.value;
    });
    const hasInstructions = computed(
      () => generatedInstructions.value.length > 0
    );

    // Methods
    const close = () => {
      emit('close');
    };

    const applyInstructions = () => {
      emit('applyInstructions', generatedInstructions.value);
      close();
    };

    const acceptInstructions = () => {
      applyInstructions();
    };

    const editInstructions = () => {
      // Reset to allow editing mode
      showConfirmationButtons.value = false;
      isApplyingInstructions.value = false;
      // Add a message to the conversation asking for edits
      const editMessage =
        'Gostaria de fazer algumas modificações nas instruções. Pode me ajudar a editá-las?';
      currentInput.value = editMessage;
    };

    const resetConversation = () => {
      resetInstructionConversation();
      currentInput.value = '';
      generatedInstructions.value = '';
      isApplyingInstructions.value = false;
      showConfirmationButtons.value = false;
    };

    const sendMessage = async () => {
      if (!canSendMessage.value) return;

      const userMessage = currentInput.value.trim();
      currentInput.value = '';

      try {
        const response = await generateInstructions(userMessage);

        // Check if this contains the final prompt ready marker
        if (isFinalPromptReady(response)) {
          generatedInstructions.value = extractInstructions(response);
          showConfirmationButtons.value = true;
        } else if (isInstructionResponse(response)) {
          // Fallback to old behavior for backward compatibility
          generatedInstructions.value = response;
          isApplyingInstructions.value = true;
          setTimeout(() => {
            applyInstructions();
          }, 2000);
        }
      } catch (err) {
        // Error is already handled in the composable
      }
    };

    const startConversation = async () => {
      if (conversationHistory.value.length === 0) {
        try {
          // Start with context if provided
          let contextMessage = '';
          if (
            props.initialContext.agentName ||
            props.initialContext.existingInstructions
          ) {
            contextMessage = initializeWithContext(props.initialContext);
          } else {
            contextMessage = 'I want to create agent instructions.';
          }

          // Send initial context and get Captain's first question
          const response = await generateInstructions(contextMessage);

          // Check if this contains the final prompt ready marker
          if (isFinalPromptReady(response)) {
            generatedInstructions.value = extractInstructions(response);
            showConfirmationButtons.value = true;
          } else if (isInstructionResponse(response)) {
            // Fallback to old behavior for backward compatibility
            generatedInstructions.value = response;
            isApplyingInstructions.value = true;
            setTimeout(() => {
              applyInstructions();
            }, 2000);
          }
        } catch (err) {
          // Error is already handled in the composable
        }
      }
    };

    const handleKeyPress = event => {
      if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        sendMessage();
      }
    };

    // Initialize conversation when modal opens
    watch(
      () => props.show,
      newShow => {
        if (newShow) {
          startConversation();
        }
      },
      { immediate: true }
    );

    return {
      t,
      conversationHistory,
      currentInput,
      isGenerating,
      generatedInstructions,
      error,
      hasMessages,
      canSendMessage,
      hasInstructions,
      isApplyingInstructions,
      showConfirmationButtons,
      close,
      resetConversation,
      sendMessage,
      applyInstructions,
      acceptInstructions,
      editInstructions,
      handleKeyPress,
    };
  },
};
</script>

<template>
  <Modal :show="show" size="medium" :on-close="close">
    <div class="flex flex-col h-[600px]">
      <!-- Header -->
      <div class="flex items-center justify-between p-6 border-b border-n-weak">
        <div>
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{ t('CAPTAIN.INSTRUCTION_GENERATOR.TITLE') }}
          </h2>
          <p class="text-sm text-n-slate-11 mt-1">
            {{ t('CAPTAIN.INSTRUCTION_GENERATOR.DESCRIPTION') }}
          </p>
        </div>
        <WootButton
          v-if="hasMessages"
          ghost
          slate
          size="sm"
          :label="t('CAPTAIN.INSTRUCTION_GENERATOR.RESET')"
          @click="resetConversation"
        />
      </div>

      <!-- Chat Area -->
      <div class="flex-1 flex flex-col overflow-hidden">
        <!-- Messages -->
        <div class="flex-1 overflow-y-auto p-4 space-y-4">
          <!-- Welcome Message -->
          <div v-if="!hasMessages" class="text-center py-8">
            <div class="text-n-slate-11 mb-4">
              <i class="i-woot-captain text-3xl" />
            </div>
            <h3 class="text-base font-medium text-n-slate-12 mb-2">
              {{ t('CAPTAIN.INSTRUCTION_GENERATOR.WELCOME.TITLE') }}
            </h3>
            <p class="text-sm text-n-slate-11">
              {{ t('CAPTAIN.INSTRUCTION_GENERATOR.WELCOME.MESSAGE') }}
            </p>
          </div>

          <!-- Conversation Messages -->
          <div
            v-for="message in conversationHistory"
            :key="message.timestamp"
            class="flex"
            :class="message.role === 'user' ? 'justify-end' : 'justify-start'"
          >
            <div
              class="max-w-[80%] rounded-lg px-4 py-2"
              :class="
                message.role === 'user'
                  ? 'bg-n-blue-6 text-white'
                  : 'bg-n-alpha-2 text-n-slate-12'
              "
            >
              <p class="text-sm whitespace-pre-wrap">{{ message.content }}</p>
            </div>
          </div>

          <!-- Loading State -->
          <div v-if="isGenerating" class="flex justify-start">
            <div class="bg-n-alpha-2 rounded-lg px-4 py-2">
              <AILoader />
            </div>
          </div>

          <!-- Error Message -->
          <div v-if="error" class="text-center">
            <div
              class="bg-n-red-1 border border-n-red-6 rounded-lg px-4 py-2 text-n-red-11"
            >
              <p class="text-sm">{{ error }}</p>
            </div>
          </div>
        </div>

        <!-- Auto-apply Status -->
        <div
          v-if="isApplyingInstructions"
          class="border-t border-n-weak p-4 bg-n-green-1"
        >
          <div class="flex items-center justify-center gap-2 text-n-green-11">
            <div
              class="animate-spin rounded-full h-4 w-4 border-b-2 border-n-green-11"
            />
            <span class="text-sm font-medium">
              {{ t('CAPTAIN.INSTRUCTION_GENERATOR.APPLYING_INSTRUCTIONS') }}
            </span>
          </div>
        </div>

        <!-- Confirmation Buttons for Final Prompt -->
        <div v-if="showConfirmationButtons" class="border-t border-n-weak p-4">
          <div class="bg-n-alpha-1 rounded-lg p-4 mb-4">
            <h4 class="text-sm font-medium text-n-slate-12 mb-2">
              {{ t('CAPTAIN.INSTRUCTION_GENERATOR.GENERATED_INSTRUCTIONS') }}
            </h4>
            <div
              data-testid="generated-instructions"
              class="text-sm text-n-slate-11 max-h-32 overflow-y-auto whitespace-pre-wrap"
            >
              {{ generatedInstructions }}
            </div>
          </div>
          <div class="flex gap-3 justify-center">
            <WootButton
              data-testid="accept-button"
              icon="i-lucide-check"
              label="Aceitar e Usar"
              @click="acceptInstructions"
            />
            <WootButton
              data-testid="edit-button"
              ghost
              icon="i-lucide-edit"
              label="Editar"
              @click="editInstructions"
            />
          </div>
        </div>

        <!-- Input Area -->
        <div
          v-if="!isApplyingInstructions && !showConfirmationButtons"
          data-testid="input-area"
          class="border-t border-n-weak p-4"
        >
          <div class="flex gap-2">
            <textarea
              v-model="currentInput"
              :placeholder="
                t('CAPTAIN.INSTRUCTION_GENERATOR.INPUT_PLACEHOLDER')
              "
              class="flex-1 resize-none border border-n-weak rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-n-blue-6 focus:border-transparent"
              rows="2"
              :disabled="isGenerating"
              @keypress="handleKeyPress"
            />
            <WootButton
              data-testid="send-button"
              :disabled="!canSendMessage"
              :loading="isGenerating"
              icon="i-lucide-send"
              @click="sendMessage"
            />
          </div>
        </div>
      </div>

      <!-- Footer Actions -->
      <div class="flex justify-between items-center p-6 border-t border-n-weak">
        <WootButton
          ghost
          slate
          :label="t('CAPTAIN.INSTRUCTION_GENERATOR.CANCEL')"
          @click="close"
        />
        <WootButton
          v-if="hasInstructions"
          :label="t('CAPTAIN.INSTRUCTION_GENERATOR.APPLY_INSTRUCTIONS')"
          @click="applyInstructions"
        />
      </div>
    </div>
  </Modal>
</template>

<style scoped>
.modal-content {
  height: 100%;
}
</style>
