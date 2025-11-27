<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  visible: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update:visible', 'confirm', 'cancel']);

const { t } = useI18n();

const selectedDate = ref('');
const selectedTime = ref('');

const minDate = computed(() => {
  const now = new Date();
  return now.toISOString().split('T')[0];
});

const minTime = computed(() => {
  if (selectedDate.value === minDate.value) {
    const now = new Date();
    now.setMinutes(now.getMinutes() + 5);
    return now.toTimeString().slice(0, 5);
  }
  return '00:00';
});

const isValid = computed(() => {
  if (!selectedDate.value || !selectedTime.value) return false;
  const scheduledDateTime = new Date(
    `${selectedDate.value}T${selectedTime.value}`
  );
  return scheduledDateTime > new Date();
});

watch(
  () => props.visible,
  newVal => {
    if (newVal) {
      const now = new Date();
      now.setMinutes(now.getMinutes() + 30);
      selectedDate.value = now.toISOString().split('T')[0];
      selectedTime.value = now.toTimeString().slice(0, 5);
    }
  }
);

function onConfirm() {
  if (!isValid.value) return;
  const scheduledDateTime = new Date(
    `${selectedDate.value}T${selectedTime.value}`
  );
  emit('confirm', scheduledDateTime.toISOString());
  emit('update:visible', false);
}

function onCancel() {
  emit('cancel');
  emit('update:visible', false);
}
</script>

<template>
  <div
    v-if="visible"
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
    @click.self="onCancel"
  >
    <div
      class="bg-n-solid-1 rounded-lg p-4 shadow-xl min-w-80 border border-n-weak"
    >
      <h3 class="text-lg font-semibold text-n-slate-12 mb-4">
        {{ t('CONVERSATION.FOOTER.SCHEDULE_MESSAGE') }}
      </h3>
      <div class="flex flex-col gap-3">
        <div>
          <label class="block text-sm text-n-slate-11 mb-1">
            {{ t('CONVERSATION.FOOTER.SCHEDULE_DATE') }}
          </label>
          <input
            v-model="selectedDate"
            type="date"
            :min="minDate"
            class="w-full px-3 py-2 border border-n-weak rounded-lg bg-n-solid-2 text-n-slate-12"
          />
        </div>
        <div>
          <label class="block text-sm text-n-slate-11 mb-1">
            {{ t('CONVERSATION.FOOTER.SCHEDULE_TIME') }}
          </label>
          <input
            v-model="selectedTime"
            type="time"
            :min="minTime"
            class="w-full px-3 py-2 border border-n-weak rounded-lg bg-n-solid-2 text-n-slate-12"
          />
        </div>
      </div>
      <div class="flex justify-end gap-2 mt-4">
        <button
          class="px-4 py-2 text-n-slate-11 hover:text-n-slate-12 rounded-lg"
          @click="onCancel"
        >
          {{ t('CONVERSATION.FOOTER.CANCEL_SCHEDULE') }}
        </button>
        <button
          :disabled="!isValid"
          class="px-4 py-2 bg-woot-500 text-white rounded-lg hover:bg-woot-600 disabled:opacity-50 disabled:cursor-not-allowed"
          @click="onConfirm"
        >
          {{ t('CONVERSATION.FOOTER.CONFIRM_SCHEDULE') }}
        </button>
      </div>
    </div>
  </div>
</template>
