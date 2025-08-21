<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useI18n } from 'vue-i18n'

const { t } = useI18n()

const props = defineProps({
  show: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['close', 'confirm'])

// Reactive state
const selectedDate = ref('')
const selectedTime = ref('')
const isValid = ref(false)

// Computed properties
const minDate = computed(() => {
  const tomorrow = new Date()
  tomorrow.setDate(tomorrow.getDate() + 1)
  return tomorrow.toISOString().split('T')[0]
})

const minTime = computed(() => {
  const now = new Date()
  const today = now.toISOString().split('T')[0]

  if (selectedDate.value === today) {
    const hours = String(now.getHours()).padStart(2, '0')
    const minutes = String(now.getMinutes() + 5).padStart(2, '0') // 5 min buffer
    return `${hours}:${minutes}`
  }
  return '00:00'
})

// Methods
const validateDateTime = () => {
  if (!selectedDate.value || !selectedTime.value) {
    isValid.value = false
    return
  }

  const selectedDateTime = new Date(`${selectedDate.value}T${selectedTime.value}`)
  const now = new Date()

  isValid.value = selectedDateTime > now
}

const handleConfirm = () => {
  if (!isValid.value) return

  const dateTime = new Date(`${selectedDate.value}T${selectedTime.value}`)
  emit('confirm', dateTime.toISOString())
}

const handleClose = () => {
  selectedDate.value = ''
  selectedTime.value = ''
  isValid.value = false
  emit('close')
}

// Watchers
watch([selectedDate, selectedTime], validateDateTime)

// Initialize with tomorrow
onMounted(() => {
  const tomorrow = new Date()
  tomorrow.setDate(tomorrow.getDate() + 1)
  selectedDate.value = tomorrow.toISOString().split('T')[0]
  selectedTime.value = '09:00'
  validateDateTime()
})
</script>

<template>
  <div
    v-if="show"
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
    @click.self="handleClose"
  >
    <div class="bg-n-solid-1 rounded-lg shadow-xl p-6 w-full max-w-md mx-4">
      <h3 class="text-lg font-semibold text-n-slate-12 mb-4">
        {{ t('CONVERSATION.FOOTER.SELECT_DATE_TIME') }}
      </h3>

      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-n-slate-11 mb-2">
            {{ t('CONVERSATION.FOOTER.DATE') }}
          </label>
          <input
            v-model="selectedDate"
            type="date"
            :min="minDate"
            class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:ring-2 focus:ring-n-blue-8 focus:border-n-blue-8"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-n-slate-11 mb-2">
            {{ t('CONVERSATION.FOOTER.TIME') }}
          </label>
          <input
            v-model="selectedTime"
            type="time"
            :min="minTime"
            class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:ring-2 focus:ring-n-blue-8 focus:border-n-blue-8"
          />
        </div>
      </div>

      <div class="flex justify-end gap-3 mt-6">
        <button
          @click="handleClose"
          class="px-4 py-2 text-sm font-medium text-n-slate-11 hover:text-n-slate-12 transition-colors"
        >
          {{ t('CONVERSATION.FOOTER.CANCEL') }}
        </button>
        <button
          @click="handleConfirm"
          :disabled="!isValid"
          class="px-4 py-2 text-sm font-medium text-white bg-n-blue-9 hover:bg-n-blue-10 disabled:bg-n-slate-6 disabled:cursor-not-allowed rounded-md transition-colors"
        >
          {{ t('CONVERSATION.FOOTER.CONFIRM') }}
        </button>
      </div>
    </div>
  </div>
</template>
