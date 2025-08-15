<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import agentsAPI from 'dashboard/api/agents';

const emit = defineEmits(['selectTemplate', 'back']);
const { t } = useI18n();
const alert = useAlert();

const templates = ref([]);
const loading = ref(false);
const selectedTemplate = ref(null);

const fetchTemplates = async () => {
  try {
    loading.value = true;
    // Get current locale from i18n
    const { locale } = useI18n();
    const currentLocale = locale.value || 'en';
    const response = await agentsAPI.getAgentTemplates(currentLocale);
    templates.value = response.data;
  } catch (error) {
    alert.error(t('CAPTAIN.ASSISTANTS.API.ERROR_MESSAGE'));
  } finally {
    loading.value = false;
  }
};

const handleSelectTemplate = () => {
  if (selectedTemplate.value) {
    emit('selectTemplate', selectedTemplate.value);
  } else {
    alert.warning(t('CAPTAIN.ASSISTANTS.TEMPLATE_SELECTION.SELECT_TEMPLATE'));
  }
};

const handleBack = () => {
  emit('back');
};

onMounted(() => {
  fetchTemplates();
});
</script>

<template>
  <div>
    <woot-modal-header
      :header-title="
        $t('CAPTAIN.ASSISTANTS.TEMPLATE_SELECTION.SELECT_TEMPLATE_TITLE')
      "
      :header-content="
        $t('CAPTAIN.ASSISTANTS.TEMPLATE_SELECTION.SELECT_TEMPLATE_DESC')
      "
    />

    <div class="p-6 space-y-4">
      <div v-if="loading" class="flex justify-center py-8">
        <div
          class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"
        />
      </div>

      <div v-else class="space-y-3 max-h-80 overflow-y-auto">
        <label
          v-for="template in templates"
          :key="template.id"
          class="flex items-start space-x-3 p-4 border rounded-lg cursor-pointer hover:bg-slate-50 transition-colors"
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
            <div class="text-sm text-slate-500 mt-1">
              {{ template.description }}
            </div>
            <div class="flex gap-2 mt-2">
              <span
                v-if="template.featureFaq"
                class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800"
              >
                {{ $t('CAPTAIN.ASSISTANTS.TEMPLATE_SELECTION.FAQ') }}
              </span>
              <span
                v-if="template.featureMemory"
                class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-purple-100 text-purple-800"
              >
                {{ $t('CAPTAIN.ASSISTANTS.TEMPLATE_SELECTION.MEMORY') }}
              </span>
            </div>
          </div>
        </label>
      </div>

      <div
        v-if="!loading && !templates.length"
        class="text-center py-8 text-slate-500"
      >
        {{ $t('CAPTAIN.ASSISTANTS.TEMPLATE_SELECTION.NO_TEMPLATES') }}
      </div>
    </div>

    <div class="flex justify-between p-6 pt-0">
      <woot-button variant="clear" color-scheme="secondary" @click="handleBack">
        <i class="i-lucide-arrow-left mr-2" />
        {{ $t('CAPTAIN.FORM.BACK') }}
      </woot-button>

      <woot-button
        color-scheme="primary"
        variant="solid"
        size="default"
        :disabled="!selectedTemplate || loading"
        @click="handleSelectTemplate"
      >
        {{ $t('CAPTAIN.ASSISTANTS.TEMPLATE_SELECTION.USE_TEMPLATE') }}
      </woot-button>
    </div>
  </div>
</template>
