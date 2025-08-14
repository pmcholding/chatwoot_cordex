<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required, email } from '@vuelidate/validators';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  template: {
    type: Object,
    default: null,
  },
  aiMode: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const agentName = ref('');
const agentEmail = ref('');
const agentInstructions = ref('');
const selectedRoleId = ref('agent');
const showCaptainModal = ref(false);

const rules = {
  agentName: { required },
  agentEmail: { required, email },
  agentInstructions: { required },
  selectedRoleId: { required },
};

const v$ = useVuelidate(rules, {
  agentName,
  agentEmail,
  agentInstructions,
  selectedRoleId,
});

const uiFlags = useMapGetter('agents/getUIFlags');
const getCustomRoles = useMapGetter('customRole/getCustomRoles');

const roles = computed(() => {
  const defaultRoles = [
    {
      id: 'administrator',
      name: 'administrator',
      label: t('AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR'),
    },
    {
      id: 'agent',
      name: 'agent',
      label: t('AGENT_MGMT.AGENT_TYPES.AGENT'),
    },
  ];

  const customRoles = getCustomRoles.value.map(role => ({
    id: role.id,
    name: `custom_${role.id}`,
    label: role.name,
  }));

  return [...defaultRoles, ...customRoles];
});

const selectedRole = computed(() =>
  roles.value.find(
    role =>
      role.id === selectedRoleId.value || role.name === selectedRoleId.value
  )
);

// Template pre-filling
const initializeTemplate = () => {
  if (props.template) {
    agentInstructions.value = props.template.instructions;
    if (props.template.name) {
      agentName.value = props.template.name;
    }
  }
};

// AI mode handling
const initializeAIMode = () => {
  if (props.aiMode) {
    showCaptainModal.value = true;
  }
};

const generateInstructions = () => {
  // Placeholder for Captain integration
  agentInstructions.value =
    'AI-generated instructions will be populated here by Captain integration.';
  showCaptainModal.value = false;
  useAlert('Instructions generated successfully');
};

onMounted(() => {
  initializeTemplate();
  initializeAIMode();
});

const addAgent = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    const payload = {
      name: agentName.value,
      email: agentEmail.value,
      instructions: agentInstructions.value,
    };

    if (selectedRole.value.name.startsWith('custom_')) {
      payload.custom_role_id = selectedRole.value.id;
    } else {
      payload.role = selectedRole.value.name;
    }

    await store.dispatch('agents/create', payload);
    useAlert(t('AGENT_MGMT.ADD.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    const {
      response: {
        data: {
          error: errorResponse = '',
          attributes: attributes = [],
          message: attrError = '',
        } = {},
      } = {},
    } = error;

    let errorMessage = '';
    if (error?.response?.status === 422 && !attributes.includes('base')) {
      errorMessage = t('AGENT_MGMT.ADD.API.EXIST_MESSAGE');
    } else {
      errorMessage = t('AGENT_MGMT.ADD.API.ERROR_MESSAGE');
    }
    useAlert(errorResponse || attrError || errorMessage);
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('AGENT_MGMT.ADD.TITLE')"
      :header-content="$t('AGENT_MGMT.ADD.DESC')"
    />
    <form class="flex flex-col items-start w-full" @submit.prevent="addAgent">
      <div class="w-full">
        <label :class="{ error: v$.agentName.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.NAME.LABEL') }}
          <input
            v-model="agentName"
            type="text"
            :placeholder="$t('AGENT_MGMT.ADD.FORM.NAME.PLACEHOLDER')"
            @input="v$.agentName.$touch"
          />
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.selectedRoleId.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.AGENT_TYPE.LABEL') }}
          <select v-model="selectedRoleId" @change="v$.selectedRoleId.$touch">
            <option v-for="role in roles" :key="role.id" :value="role.id">
              {{ role.label }}
            </option>
          </select>
          <span v-if="v$.selectedRoleId.$error" class="message">
            {{ $t('AGENT_MGMT.ADD.FORM.AGENT_TYPE.ERROR') }}
          </span>
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.agentEmail.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.EMAIL.LABEL') }}
          <input
            v-model="agentEmail"
            type="email"
            :placeholder="$t('AGENT_MGMT.ADD.FORM.EMAIL.PLACEHOLDER')"
            @input="v$.agentEmail.$touch"
          />
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.agentInstructions.$error }">
          Instructions
          <textarea
            v-model="agentInstructions"
            rows="4"
            placeholder="Enter agent instructions..."
            @input="v$.agentInstructions.$touch"
          />
        </label>
        <div class="flex justify-between items-center mt-2">
          <Button
            v-if="!showCaptainModal"
            faded
            size="small"
            label="Generate with AI"
            @click="showCaptainModal = true"
          />
        </div>
      </div>

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <Button
          faded
          slate
          type="reset"
          :label="$t('AGENT_MGMT.ADD.CANCEL_BUTTON_TEXT')"
          @click.prevent="emit('close')"
        />
        <Button
          type="submit"
          :label="$t('AGENT_MGMT.ADD.FORM.SUBMIT')"
          :disabled="v$.$invalid || uiFlags.isCreating"
          :is-loading="uiFlags.isCreating"
        />
      </div>
    </form>

    <!-- Captain Modal Placeholder -->
    <woot-modal
      v-if="showCaptainModal"
      :show="showCaptainModal"
      @close="showCaptainModal = false"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4">
          AI Agent Instructions Generator (Captain)
        </h3>
        <p class="text-sm text-slate-600 mb-4">
          This will integrate with the Captain modal for AI-assisted
          instructions generation.
        </p>
        <div class="flex justify-end gap-2">
          <Button faded label="Cancel" @click="showCaptainModal = false" />
          <Button label="Generate Instructions" @click="generateInstructions" />
        </div>
      </div>
    </woot-modal>
  </div>
</template>
