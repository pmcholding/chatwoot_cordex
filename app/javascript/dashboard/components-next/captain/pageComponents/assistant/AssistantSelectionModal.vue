<script setup>
import { ref } from 'vue';
import TemplateSelectionScreen from './TemplateSelectionScreen.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits([
  'close',
  'useTemplate',
  'createFromScratch',
  'createWithAi',
]);

const showTemplateSelection = ref(false);

const handleUseTemplate = () => {
  showTemplateSelection.value = true;
};

const handleCreateFromScratch = () => {
  emit('createFromScratch');
};

const handleCreateWithAI = () => {
  emit('createWithAi');
};

const handleClose = () => {
  emit('close');
};

const goBackToSelection = () => {
  showTemplateSelection.value = false;
};

const handleTemplateSelected = template => {
  emit('useTemplate', template);
};
</script>

<template>
  <!-- Template Selection Screen -->
  <div v-if="showTemplateSelection">
    <TemplateSelectionScreen
      @select-template="handleTemplateSelected"
      @back="goBackToSelection"
    />
  </div>

  <!-- Main Selection Screen -->
  <div v-else>
    <woot-modal-header
      :header-title="$t('CAPTAIN.ASSISTANTS.TEMPLATE_SELECTION.TITLE')"
      :header-content="$t('CAPTAIN.ASSISTANTS.TEMPLATE_SELECTION.DESCRIPTION')"
    />
    <div class="p-6 space-y-6">
      <!-- Option 1: Use Template -->
      <div
        class="border border-slate-200 rounded-lg p-4 space-y-4 cursor-pointer hover:bg-slate-50 transition-colors"
        @click="handleUseTemplate"
      >
        <div class="flex items-center space-x-3">
          <div
            class="flex-shrink-0 w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center"
          >
            <i class="i-lucide-file-text text-blue-600" />
          </div>
          <div>
            <h3 class="text-lg font-medium text-slate-900">
              {{ $t('CAPTAIN.ASSISTANTS.TEMPLATE_SELECTION.USE_TEMPLATE') }}
            </h3>
            <p class="text-sm text-slate-500">
              {{
                $t('CAPTAIN.ASSISTANTS.TEMPLATE_SELECTION.USE_TEMPLATE_DESC')
              }}
            </p>
          </div>
        </div>
      </div>

      <!-- Option 2: Create from Scratch -->
      <div
        class="border border-slate-200 rounded-lg p-4 space-y-4 cursor-pointer hover:bg-slate-50 transition-colors"
        @click="handleCreateFromScratch"
      >
        <div class="flex items-center space-x-3">
          <div
            class="flex-shrink-0 w-8 h-8 bg-green-100 rounded-full flex items-center justify-center"
          >
            <i class="i-lucide-plus text-green-600" />
          </div>
          <div>
            <h3 class="text-lg font-medium text-slate-900">
              {{
                $t('CAPTAIN.ASSISTANTS.TEMPLATE_SELECTION.CREATE_FROM_SCRATCH')
              }}
            </h3>
            <p class="text-sm text-slate-500">
              {{
                $t(
                  'CAPTAIN.ASSISTANTS.TEMPLATE_SELECTION.CREATE_FROM_SCRATCH_DESC'
                )
              }}
            </p>
          </div>
        </div>
      </div>

      <!-- Option 3: Create with AI -->
      <div
        class="border border-slate-200 rounded-lg p-4 space-y-4 cursor-pointer hover:bg-slate-50 transition-colors"
        @click="handleCreateWithAI"
      >
        <div class="flex items-center space-x-3">
          <div
            class="flex-shrink-0 w-8 h-8 bg-purple-100 rounded-full flex items-center justify-center"
          >
            <i class="i-lucide-sparkles text-purple-600" />
          </div>
          <div>
            <h3 class="text-lg font-medium text-slate-900">
              {{ $t('CAPTAIN.ASSISTANTS.TEMPLATE_SELECTION.CREATE_WITH_AI') }}
            </h3>
            <p class="text-sm text-slate-500">
              {{ $t('CAPTAIN.ASSISTANTS.TEMPLATE_SELECTION.AI_DESCRIPTION') }}
            </p>
          </div>
        </div>
      </div>
    </div>

    <div class="flex justify-end p-6 pt-0">
      <Button variant="ghost" color="slate" @click="handleClose">
        {{ $t('CAPTAIN.FORM.CANCEL') }}
      </Button>
    </div>
  </div>
</template>
