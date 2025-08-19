<script setup>
import { ref, onMounted, computed } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import FeatureToggle from 'dashboard/components/widgets/FeatureToggle.vue';
import SettingsSection from 'dashboard/components/SettingsSection.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import BackButton from 'dashboard/components/widgets/BackButton.vue';
import wootModal from 'dashboard/components/Modal.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useI18n } from 'vue-i18n';

const store = useStore();
const { t } = useI18n();

// Reactive data
const stages = ref([]);
const isLoading = ref(false);
const showStageModal = ref(false);
const editingStage = ref(null);
const newStage = ref({ name: '', color: '#667085' });

// Settings
const autoAssignConversations = ref(false);
const showConversationCount = ref(true);
const defaultStageId = ref(null);
const defaultFilters = ref({
  inboxId: null,
  assigneeId: null,
  labelIds: [],
});

// Computed
const isEditMode = computed(() => !!editingStage.value);
const stageColors = [
  '#667085',
  '#065f46',
  '#7c2d12',
  '#991b1b',
  '#7c2d12',
  '#a21caf',
  '#6b21a8',
  '#3730a3',
  '#1e40af',
  '#0369a1',
];

const inboxes = computed(() => store.getters['inboxes/getInboxes']);
const agents = computed(() => store.getters['agents/getAgents']);
// const labels = computed(() => store.getters['labels/getLabels']);

// Methods
const fetchStages = async () => {
  isLoading.value = true;
  try {
    await store.dispatch('kanban/fetchInitial');
    stages.value = store.getters['kanban/orderedStages'].map(stage => ({
      ...stage,
      conversations_count: stage.count || 0,
    }));
  } catch (error) {
    useAlert(error.message || 'Failed to fetch stages');
    // Fallback para dados simulados em caso de erro
    stages.value = [
      { id: 1, name: 'New', color: '#667085', conversations_count: 5 },
      { id: 2, name: 'In Progress', color: '#065f46', conversations_count: 3 },
      { id: 3, name: 'Waiting', color: '#7c2d12', conversations_count: 2 },
      { id: 4, name: 'Resolved', color: '#065f46', conversations_count: 10 },
    ];
  } finally {
    isLoading.value = false;
  }
};

const openStageModal = (stage = null) => {
  if (stage) {
    editingStage.value = stage;
    newStage.value = { ...stage };
  } else {
    editingStage.value = null;
    newStage.value = { name: '', color: '#667085' };
  }
  showStageModal.value = true;
};

const closeStageModal = () => {
  showStageModal.value = false;
  editingStage.value = null;
  newStage.value = { name: '', color: '#667085' };
};

const saveStage = async () => {
  if (!newStage.value.name.trim()) {
    useAlert('Stage name is required');
    return;
  }

  try {
    if (isEditMode.value) {
      await store.dispatch('kanban/updateStage', {
        id: editingStage.value.id,
        name: newStage.value.name,
        color: newStage.value.color,
      });
      useAlert('Stage updated successfully');
    } else {
      await store.dispatch('kanban/createStage', {
        name: newStage.value.name,
        color: newStage.value.color,
      });
      useAlert('Stage created successfully');
    }
    closeStageModal();
    fetchStages();
  } catch (error) {
    useAlert(error.message || 'Failed to save stage');
  }
};

const deleteStage = async stage => {
  if (!window.confirm(t('KANBAN.SETTINGS.STAGES.DELETE_CONFIRM'))) {
    return;
  }

  try {
    await store.dispatch('kanban/deleteStage', { id: stage.id });
    useAlert('Stage deleted successfully');
    fetchStages();
  } catch (error) {
    useAlert(error.message || 'Failed to delete stage');
  }
};

const reorderStages = async newOrder => {
  try {
    await store.dispatch('kanban/reorderStages', newOrder);
    useAlert('Stages reordered successfully');
    fetchStages();
  } catch (error) {
    useAlert(error.message || 'Failed to reorder stages');
  }
};

// Drag and drop functionality
const draggedStage = ref(null);

const onDragStart = (event, stage) => {
  draggedStage.value = stage;
  event.dataTransfer.effectAllowed = 'move';
};

const onDragOver = event => {
  event.preventDefault();
  event.dataTransfer.dropEffect = 'move';
};

const onDrop = (event, targetStage) => {
  event.preventDefault();

  if (!draggedStage.value || draggedStage.value.id === targetStage.id) {
    return;
  }

  const currentStages = [...stages.value];
  const draggedIndex = currentStages.findIndex(
    s => s.id === draggedStage.value.id
  );
  const targetIndex = currentStages.findIndex(s => s.id === targetStage.id);

  // Remove dragged stage and insert at new position
  const [draggedStageData] = currentStages.splice(draggedIndex, 1);
  currentStages.splice(targetIndex, 0, draggedStageData);

  // Update positions
  const positions = currentStages.map((stage, index) => ({
    id: stage.id,
    position: index + 1,
  }));

  // Update local state immediately
  stages.value = currentStages;

  // Update backend
  reorderStages(positions);

  draggedStage.value = null;
};

const saveGeneralSettings = async () => {
  try {
    const settings = {
      auto_assign_conversations: autoAssignConversations.value,
      show_conversation_count: showConversationCount.value,
      default_stage_id: defaultStageId.value,
      default_filters: defaultFilters.value,
    };

    await store.dispatch('kanbanSettings/update', settings);
    useAlert('Settings saved successfully');
  } catch (error) {
    useAlert(error.message || 'Failed to save settings');
  }
};

onMounted(async () => {
  await store.dispatch('kanbanSettings/get');
  const s = store.getters['kanbanSettings/getSettings'];
  autoAssignConversations.value = !!s.auto_assign_conversations;
  showConversationCount.value = s.show_conversation_count !== false;
  defaultStageId.value = s.default_stage_id || null;
  if (s.default_filters) {
    defaultFilters.value = {
      inboxId: s.default_filters.inboxId || null,
      assigneeId: s.default_filters.assigneeId || null,
      labelIds: s.default_filters.labelIds || [],
    };
  }

  fetchStages();
  store.dispatch('inboxes/get');
  store.dispatch('agents/get');
  store.dispatch('labels/get');
});
</script>

<template>
  <FeatureToggle :feature-key="FEATURE_FLAGS.KANBAN">
    <div class="flex flex-col h-screen w-full min-w-0">
      <!-- Header Section -->
      <section class="flex flex-col gap-1 pt-10 pb-5 px-8">
        <div>
          <BackButton compact />
        </div>
        <div class="flex justify-between w-full gap-5">
          <div class="flex flex-col gap-2">
            <div>
              <span class="text-xl font-medium text-n-slate-12">
                {{ t('KANBAN.SETTINGS.TITLE') }}
              </span>
              <p class="text-n-slate-11 text-sm mt-2">
                {{ t('KANBAN.SETTINGS.SUBTITLE') }}
              </p>
            </div>
          </div>
        </div>
      </section>

      <!-- Content Section -->
      <section class="flex-1 overflow-y-auto px-8">
        <div class="flex flex-col gap-3">
          <!-- Stages Management Section -->
          <SettingsSection
            :title="t('KANBAN.SETTINGS.STAGES.TITLE')"
            :sub-title="t('KANBAN.SETTINGS.STAGES.SUBTITLE')"
          >
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <p class="text-sm text-n-slate-11">
                  {{ t('KANBAN.SETTINGS.STAGES.REORDER') }}
                </p>
                <NextButton
                  :label="t('KANBAN.SETTINGS.STAGES.ADD_STAGE')"
                  @click="openStageModal()"
                />
              </div>

              <div v-if="isLoading" class="py-8 text-center">
                <woot-loading-state />
              </div>

              <div v-else class="space-y-3">
                <div
                  v-for="stage in stages"
                  :key="stage.id"
                  draggable="true"
                  class="flex items-center justify-between p-4 border border-n-weak rounded-lg bg-n-background hover:bg-n-surface-2 cursor-move transition-all duration-200"
                  :class="{ 'opacity-50': draggedStage?.id === stage.id }"
                  @dragstart="onDragStart($event, stage)"
                  @dragover="onDragOver"
                  @drop="onDrop($event, stage)"
                >
                  <div class="flex items-center space-x-3">
                    <div
                      class="flex items-center justify-center w-6 h-6 text-n-slate-9 hover:text-n-slate-12"
                    >
                      <svg
                        class="w-4 h-4"
                        fill="currentColor"
                        viewBox="0 0 20 20"
                      >
                        <path
                          d="M7 2a2 2 0 1 0 0 4 2 2 0 0 0 0-4zM7 8a2 2 0 1 0 0 4 2 2 0 0 0 0-4zM7 14a2 2 0 1 0 0 4 2 2 0 0 0 0-4zM13 2a2 2 0 1 0 0 4 2 2 0 0 0 0-4zM13 8a2 2 0 1 0 0 4 2 2 0 0 0 0-4zM13 14a2 2 0 1 0 0 4 2 2 0 0 0 0-4z"
                        />
                      </svg>
                    </div>
                    <div
                      class="w-4 h-4 rounded-full"
                      :style="{ backgroundColor: stage.color }"
                    />
                    <span class="font-medium text-n-slate-12">{{
                      stage.name
                    }}</span>
                    <span class="text-sm text-n-slate-11">{{
                      t('KANBAN.SETTINGS.STAGES.CONVERSATIONS_COUNT', {
                        count: stage.conversations_count || 0,
                      })
                    }}</span>
                  </div>
                  <div class="flex items-center space-x-2">
                    <NextButton
                      ghost
                      small
                      :label="t('KANBAN.SETTINGS.EDIT')"
                      @click="openStageModal(stage)"
                    />
                    <NextButton
                      ghost
                      small
                      variant="danger"
                      :label="t('KANBAN.SETTINGS.DELETE')"
                      @click="deleteStage(stage)"
                    />
                  </div>
                </div>
              </div>
            </div>
          </SettingsSection>

          <!-- General Settings Section -->
          <SettingsSection
            :title="t('KANBAN.SETTINGS.GENERAL.TITLE')"
            :sub-title="t('KANBAN.SETTINGS.GENERAL.SUBTITLE')"
          >
            <div class="space-y-6">
              <div class="flex items-center justify-between">
                <div>
                  <label class="block text-sm font-medium text-n-slate-12 mb-1">
                    {{ t('KANBAN.SETTINGS.GENERAL.AUTO_ASSIGN') }}
                  </label>
                  <p class="text-sm text-n-slate-11">
                    {{ t('KANBAN.SETTINGS.GENERAL.AUTO_ASSIGN_HELP') }}
                  </p>
                </div>
                <label class="inline-flex items-center">
                  <input
                    v-model="autoAssignConversations"
                    type="checkbox"
                    class="form-checkbox h-5 w-5 text-blue-600"
                  />
                </label>
              </div>

              <div class="flex items-center justify-between">
                <div>
                  <label class="block text-sm font-medium text-n-slate-12 mb-1">
                    {{ t('KANBAN.SETTINGS.GENERAL.SHOW_CONVERSATION_COUNT') }}
                  </label>
                  <p class="text-sm text-n-slate-11">
                    {{
                      t('KANBAN.SETTINGS.GENERAL.SHOW_CONVERSATION_COUNT_HELP')
                    }}
                  </p>
                </div>
                <label class="inline-flex items-center">
                  <input
                    v-model="showConversationCount"
                    type="checkbox"
                    class="form-checkbox h-5 w-5 text-blue-600"
                  />
                </label>
              </div>

              <div>
                <label class="block text-sm font-medium text-n-slate-12 mb-2">
                  {{ t('KANBAN.SETTINGS.GENERAL.DEFAULT_STAGE') }}
                </label>
                <select
                  v-model="defaultStageId"
                  class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-background text-n-slate-12"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.GENERAL.DEFAULT_STAGE_SELECT') }}
                  </option>
                  <option
                    v-for="stage in stages"
                    :key="stage.id"
                    :value="stage.id"
                  >
                    {{ stage.name }}
                  </option>
                </select>
                <p class="text-sm text-n-slate-11 mt-1">
                  {{ t('KANBAN.SETTINGS.GENERAL.DEFAULT_STAGE_HELP') }}
                </p>
              </div>
            </div>
          </SettingsSection>

          <!-- Default Filters Section -->
          <SettingsSection
            :title="t('KANBAN.SETTINGS.FILTERS.TITLE')"
            :sub-title="t('KANBAN.SETTINGS.FILTERS.SUBTITLE')"
            :show-border="false"
          >
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-n-slate-12 mb-2">
                  {{ t('KANBAN.SETTINGS.FILTERS.INBOX_FILTER') }}
                </label>
                <select
                  v-model="defaultFilters.inboxId"
                  class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-background text-n-slate-12"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.FILTERS.ALL_INBOXES') }}
                  </option>
                  <option
                    v-for="inbox in inboxes"
                    :key="inbox.id"
                    :value="inbox.id"
                  >
                    {{ inbox.name }}
                  </option>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-n-slate-12 mb-2">
                  {{ t('KANBAN.SETTINGS.FILTERS.ASSIGNEE_FILTER') }}
                </label>
                <select
                  v-model="defaultFilters.assigneeId"
                  class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-background text-n-slate-12"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.FILTERS.ALL_ASSIGNEES') }}
                  </option>
                  <option
                    v-for="agent in agents"
                    :key="agent.id"
                    :value="agent.id"
                  >
                    {{ agent.name }}
                  </option>
                </select>
              </div>
            </div>
          </SettingsSection>

          <!-- Save Button -->
          <SettingsSection :show-border="false">
            <NextButton
              :label="t('KANBAN.SETTINGS.SAVE_SETTINGS')"
              @click="saveGeneralSettings"
            />
          </SettingsSection>
        </div>
      </section>

      <!-- Stage Modal -->
      <woot-modal v-model:show="showStageModal" :on-close="closeStageModal">
        <woot-modal-header
          :header-title="
            isEditMode
              ? t('KANBAN.SETTINGS.EDIT') + ' Stage'
              : t('KANBAN.SETTINGS.CREATE')
          "
          :header-content="
            isEditMode
              ? 'Edit the stage details'
              : 'Create a new stage for your kanban board'
          "
        />
        <form class="space-y-4" @submit.prevent="saveStage">
          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-2">
              {{ t('KANBAN.SETTINGS.STAGES.NAME_LABEL') }}
            </label>
            <woot-input
              v-model="newStage.name"
              :placeholder="t('KANBAN.SETTINGS.STAGES.NAME_PLACEHOLDER')"
              required
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-2">
              {{ t('KANBAN.SETTINGS.STAGES.COLOR_LABEL') }}
            </label>
            <div class="flex space-x-2">
              <button
                v-for="color in stageColors"
                :key="color"
                type="button"
                class="w-8 h-8 rounded-full border-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                :class="
                  newStage.color === color
                    ? 'border-n-slate-12'
                    : 'border-n-weak'
                "
                :style="{ backgroundColor: color }"
                @click="newStage.color = color"
              />
            </div>
          </div>

          <div class="flex justify-end space-x-3 pt-4">
            <NextButton
              ghost
              :label="t('KANBAN.SETTINGS.STAGES.CANCEL')"
              @click="closeStageModal"
            />
            <NextButton
              type="submit"
              :label="t('KANBAN.SETTINGS.STAGES.SAVE')"
            />
          </div>
        </form>
      </woot-modal>
    </div>
  </FeatureToggle>
</template>
