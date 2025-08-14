<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import agentsAPI from 'dashboard/api/agents';
import { useAlert } from 'dashboard/composables';

const emit = defineEmits([
  'close',
  'useTemplate',
  'createFromScratch',
  'createWithAI',
]);
const { t } = useI18n();
const alert = useAlert();

const templates = ref([]);
const loading = ref(false);
const selectedTemplate = ref(null);

const fetchTemplates = async () => {
  try {
    loading.value = true;
    const response = await agentsAPI.getAgentTemplates();
    templates.value = response.data;
  } catch (error) {
    alert.error(t('AGENT_MGMT.API.ERROR_MESSAGE'));
  } finally {
    loading.value = false;
  }
};

const handleUseTemplate = () => {
  if (selectedTemplate.value) {
    emit('useTemplate', selectedTemplate.value);
  } else {
    alert.warning(t('AGENT_MGMT.TEMPLATE_SELECTION.SELECT_TEMPLATE'));
  }
};

const handleCreateFromScratch = () => {
  emit('createFromScratch');
};

const handleCreateWithAI = () => {
  emit('createWithAI');
};

const handleClose = () => {
  emit('close');
};

onMounted(() => {
  fetchTemplates();
});
</script>

<template>
  <woot-modal-header
    :header-title="$t('AGENT_MGMT.TEMPLATE_SELECTION.TITLE')"
    :header-content="$t('AGENT_MGMT.TEMPLATE_SELECTION.SELECT_TEMPLATE')"
  />
  <div class="p-6 space-y-6">
    <!-- Option 1: Use Template -->
    <div class="border border-slate-200 rounded-lg p-4 space-y-4">
      <div class="flex items-center space-x-3">
        <div
          class="flex-shrink-0 w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center"
        >
          <i class="i-lucide-file-text text-blue-600" />
        </div>
        <div>
          <h3 class="text-lg font-medium text-slate-900">
            {{ $t('AGENT_MGMT.TEMPLATE_SELECTION.USE_TEMPLATE') }}
          </h3>
          <p class="text-sm text-slate-500">
            {{ $t('AGENT_MGMT.TEMPLATE_SELECTION.SELECT_TEMPLATE') }}
          </p>
        </div>
      </div>

      <div v-if="loading" class="flex items-center justify-center py-8">
        <div
          class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"
        />
      </div>

      <div
        v-else-if="templates.length === 0"
        class="text-center py-8 text-slate-500"
      >
        {{ $t('AGENT_MGMT.TEMPLATE_SELECTION.NO_TEMPLATES') }}
      </div>

      <div v-else class="space-y-2 max-h-40 overflow-y-auto">
        <label
          v-for="template in templates"
          :key="template.id"
          class="flex items-start space-x-3 p-3 border rounded-lg cursor-pointer hover:bg-slate-50 transition-colors"
          :class="{
            'border-blue-500 bg-blue-50': selectedTemplate?.id === template.id,
          }"
        >
          <input
            v-model="selectedTemplate"
            type="radio"
            :value="template"
            class="mt-1 text-blue-600 border-slate-300 focus:ring-blue-500"
          />
          <div class="flex-1 min-w-0">
            <div class="text-sm font-medium text-slate-900">
              {{ template.name }}
            </div>
            <div class="text-sm text-slate-500 truncate">
              {{ template.description }}
            </div>
          </div>
        </label>
      </div>

      <woot-button
        color-scheme="primary"
        variant="solid"
        size="default"
        :disabled="!selectedTemplate || loading"
        class="w-full"
        @click="handleUseTemplate"
      >
        {{ $t('AGENT_MGMT.TEMPLATE_SELECTION.USE_TEMPLATE') }}
      </woot-button>
    </div>

    <!-- Option 2: Create from Scratch -->
    <div class="border border-slate-200 rounded-lg p-4 space-y-4">
      <div class="flex items-center space-x-3">
        <div
          class="flex-shrink-0 w-8 h-8 bg-green-100 rounded-full flex items-center justify-center"
        >
          <i class="i-lucide-plus text-green-600" />
        </div>
        <div>
          <h3 class="text-lg font-medium text-slate-900">
            {{ $t('AGENT_MGMT.TEMPLATE_SELECTION.CREATE_FROM_SCRATCH') }}
          </h3>
          <p class="text-sm text-slate-500">
            {{ $t('AGENT_MGMT.ADD.DESC') }}
          </p>
        </div>
      </div>

      <woot-button
        color-scheme="success"
        variant="solid"
        size="default"
        class="w-full"
        @click="handleCreateFromScratch"
      >
        {{ $t('AGENT_MGMT.TEMPLATE_SELECTION.CREATE_FROM_SCRATCH') }}
      </woot-button>
    </div>

    <!-- Option 3: Create with AI -->
    <div class="border border-slate-200 rounded-lg p-4 space-y-4">
      <div class="flex items-center space-x-3">
        <div
          class="flex-shrink-0 w-8 h-8 bg-purple-100 rounded-full flex items-center justify-center"
        >
          <i class="i-lucide-sparkles text-purple-600" />
        </div>
        <div>
          <h3 class="text-lg font-medium text-slate-900">
            {{ $t('AGENT_MGMT.TEMPLATE_SELECTION.CREATE_WITH_AI') }}
          </h3>
          <p class="text-sm text-slate-500">
            {{ $t('AGENT_MGMT.TEMPLATE_SELECTION.AI_DESCRIPTION') }}
          </p>
        </div>
      </div>

      <woot-button
        color-scheme="secondary"
        variant="solid"
        size="default"
        class="w-full"
        @click="handleCreateWithAI"
      >
        {{ $t('AGENT_MGMT.TEMPLATE_SELECTION.CREATE_WITH_AI') }}
      </woot-button>
    </div>

    <!-- Cancel Button -->
    <div class="flex justify-end pt-4 border-t border-slate-200">
      <woot-button
        color-scheme="secondary"
        variant="clear"
        size="default"
        @click="handleClose"
      >
        {{ $t('AGENT_MGMT.ADD.CANCEL_BUTTON_TEXT') }}
      </woot-button>
    </div>
  </div>
</template>
