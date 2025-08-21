<script setup>
import { computed, onMounted, ref } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import AssistantCard from 'dashboard/components-next/captain/assistant/AssistantCard.vue';
import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import AssistantPageEmptyState from 'dashboard/components-next/captain/pageComponents/emptyStates/AssistantPageEmptyState.vue';
import FeatureSpotlightPopover from 'dashboard/components-next/feature-spotlight/FeatureSpotlightPopover.vue';
import LimitBanner from 'dashboard/components-next/captain/pageComponents/response/LimitBanner.vue';
import AssistantSelectionModal from 'dashboard/components-next/captain/pageComponents/assistant/AssistantSelectionModal.vue';
import CreateAssistantDialog from 'dashboard/components-next/captain/pageComponents/assistant/CreateAssistantDialog.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { useRouter } from 'vue-router';

const router = useRouter();

const store = useStore();
const uiFlags = useMapGetter('captainAssistants/getUIFlags');
const assistants = useMapGetter('captainAssistants/getRecords');
const isFetching = computed(() => uiFlags.value.fetchingList);

const selectedAssistant = ref(null);
const deleteAssistantDialog = ref(null);
const showSelectionModal = ref(false);
const showCreateDialog = ref(false);
const selectedTemplate = ref(null);
const aiMode = ref(false);

// Assistant name prompt dialog refs/state
const nameDialog = ref(null);
const newAssistantName = ref('');
const isCreatingAI = ref(false);

const handleDelete = () => {
  deleteAssistantDialog.value.dialogRef.open();
};

const handleCreate = () => {
  showSelectionModal.value = true;
};

const hideSelectionModal = () => {
  showSelectionModal.value = false;
  selectedTemplate.value = null;
  aiMode.value = false;
};

const handleUseTemplate = async template => {
  try {
    // Create assistant with template data
    const assistantFromTemplate = {
      name: template.name || 'Template Assistant',
      description: template.description || 'Assistant created from template',
      config: {
        product_name: template.config?.product_name || '',
        feature_faq: template.config?.feature_faq || false,
        feature_memory: template.config?.feature_memory || false,
        instructions:
          template.instructions || template.config?.instructions || '',
        ...template.config,
      },
    };

    const createdAssistant = await store.dispatch(
      'captainAssistants/create',
      assistantFromTemplate
    );

    // Close the selection modal
    showSelectionModal.value = false;

    // Navigate to the edit page with template data pre-filled
    router.push({
      name: 'captain_assistants_edit',
      params: { assistantId: createdAssistant.id },
    });
  } catch (error) {
    // Fallback to the regular creation dialog
    selectedTemplate.value = template;
    aiMode.value = false;
    showSelectionModal.value = false;
    showCreateDialog.value = true;
  }
};

const handleCreateFromScratch = async () => {
  try {
    // Create a basic assistant first
    const basicAssistant = {
      name: 'New Assistant',
      description: 'Assistant description',
      config: {
        product_name: '',
        feature_faq: false,
        feature_memory: false,
      },
    };

    const createdAssistant = await store.dispatch(
      'captainAssistants/create',
      basicAssistant
    );

    // Close the selection modal
    showSelectionModal.value = false;

    // Navigate to the edit page (without AI mode)
    router.push({
      name: 'captain_assistants_edit',
      params: { assistantId: createdAssistant.id },
    });
  } catch (error) {
    // Fallback to the regular creation dialog
    selectedTemplate.value = null;
    aiMode.value = false;
    showSelectionModal.value = false;
    showCreateDialog.value = true;
  }
};

// Open name prompt first, then create with AI
const handleCreateWithAI = () => {
  newAssistantName.value = '';
  isCreatingAI.value = true;
  nameDialog.value?.open();
};

const confirmCreateWithAI = async () => {
  try {
    const name = (newAssistantName.value || '').trim();
    if (!name) {
      // Fallback default if empty
      newAssistantName.value = '';
    }

    const assistantPayload = {
      name: name || 'New AI Assistant',
      description: 'AI-generated assistant',
      config: {
        product_name: '',
        feature_faq: false,
        feature_memory: false,
      },
    };

    const createdAssistant = await store.dispatch(
      'captainAssistants/create',
      assistantPayload
    );

    // Close dialogs
    nameDialog.value?.close();
    showSelectionModal.value = false;

    // Navigate to the edit page with AI mode
    router.push({
      name: 'captain_assistants_edit',
      params: { assistantId: createdAssistant.id },
      query: { aiMode: 'true' },
    });
  } catch (error) {
    // Fallback to the regular creation dialog
    selectedTemplate.value = null;
    aiMode.value = true;
    showSelectionModal.value = false;
    showCreateDialog.value = true;
  } finally {
    isCreatingAI.value = false;
  }
};

const hideCreateDialog = () => {
  showCreateDialog.value = false;
  selectedTemplate.value = null;
  aiMode.value = false;
};

const handleEdit = () => {
  router.push({
    name: 'captain_assistants_edit',
    params: { assistantId: selectedAssistant.value.id },
  });
};

const handleViewConnectedInboxes = () => {
  router.push({
    name: 'captain_assistants_inboxes_index',
    params: { assistantId: selectedAssistant.value.id },
  });
};

const handleAction = ({ action, id }) => {
  selectedAssistant.value = assistants.value.find(
    assistant => id === assistant.id
  );
  if (action === 'delete') {
    handleDelete();
  }
  if (action === 'edit') {
    handleEdit();
  }
  if (action === 'viewConnectedInboxes') {
    handleViewConnectedInboxes();
  }
};

onMounted(() => store.dispatch('captainAssistants/get'));
</script>

<template>
  <PageLayout
    :header-title="$t('CAPTAIN.ASSISTANTS.HEADER')"
    :button-label="$t('CAPTAIN.ASSISTANTS.ADD_NEW')"
    :button-policy="['administrator']"
    :show-pagination-footer="false"
    :is-fetching="isFetching"
    :is-empty="!assistants.length"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
    @click="handleCreate"
  >
    <template #knowMore>
      <FeatureSpotlightPopover
        :button-label="$t('CAPTAIN.HEADER_KNOW_MORE')"
        :title="$t('CAPTAIN.ASSISTANTS.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
        :note="$t('CAPTAIN.ASSISTANTS.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
        fallback-thumbnail="/assets/images/dashboard/captain/assistant-popover-light.svg"
        fallback-thumbnail-dark="/assets/images/dashboard/captain/assistant-popover-dark.svg"
        learn-more-url=""
      />
    </template>
    <template #emptyState>
      <AssistantPageEmptyState @click="handleCreate" />
    </template>

    <template #paywall>
      <CaptainPaywall />
    </template>

    <template #body>
      <LimitBanner class="mb-5" />

      <div class="flex flex-col gap-4">
        <AssistantCard
          v-for="assistant in assistants"
          :id="assistant.id"
          :key="assistant.id"
          :name="assistant.name"
          :description="assistant.description"
          :updated-at="assistant.updated_at || assistant.created_at"
          :created-at="assistant.created_at"
          @action="handleAction"
        />
      </div>
    </template>

    <DeleteDialog
      v-if="selectedAssistant"
      ref="deleteAssistantDialog"
      :entity="selectedAssistant"
      type="Assistants"
    />

    <!-- Prompt for Assistant Name when creating with AI -->
    <Dialog
      ref="nameDialog"
      type="edit"
      :title="
        $t('CAPTAIN.ASSISTANTS.CREATE_WITH_AI_NAME_TITLE') ||
        'Nome do Assistente'
      "
      :description="
        $t('CAPTAIN.ASSISTANTS.CREATE_WITH_AI_NAME_DESC') ||
        'Digite o nome do assistente antes de gerar com IA'
      "
      confirm-button-label="Continuar"
      show-cancel-button
      show-confirm-button
      :disable-confirm-button="!newAssistantName"
      :is-loading="false"
      @confirm="confirmCreateWithAI"
      @close="() => (isCreatingAI = false)"
    >
      <Input
        id="assistant-name"
        v-model="newAssistantName"
        type="text"
        placeholder="Ex: Assistente de Suporte"
        label="Nome"
      />
    </Dialog>

    <!-- Assistant Selection Modal -->
    <woot-modal
      v-model:show="showSelectionModal"
      :on-close="hideSelectionModal"
    >
      <AssistantSelectionModal
        @close="hideSelectionModal"
        @use-template="handleUseTemplate"
        @create-from-scratch="handleCreateFromScratch"
        @create-with-ai="handleCreateWithAI"
      />
    </woot-modal>

    <!-- Create Assistant Dialog -->
    <woot-modal v-model:show="showCreateDialog" :on-close="hideCreateDialog">
      <CreateAssistantDialog
        type="create"
        :template="selectedTemplate"
        :ai-mode="aiMode"
        @close="hideCreateDialog"
      />
    </woot-modal>
  </PageLayout>
</template>
