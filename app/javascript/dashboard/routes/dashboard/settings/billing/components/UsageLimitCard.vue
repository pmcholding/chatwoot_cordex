<script setup>
import { computed } from 'vue';

const props = defineProps({
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    required: true,
  },
  current: {
    type: Number,
    required: true,
  },
  limit: {
    type: Number,
    default: null,
  },
  icon: {
    type: String,
    required: true,
  },
  color: {
    type: String,
    default: 'blue',
  },
});

const iconClass = computed(() => {
  const iconMap = {
    inbox: 'i-lucide-inbox',
    users: 'i-lucide-users',
    robot: 'i-woot-captain',
    documents: 'i-lucide-file-text',
  };
  return iconMap[props.icon] || 'i-lucide-circle';
});

const iconBgClass = computed(() => {
  const colorMap = {
    blue: 'bg-blue-100 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400',
    green:
      'bg-green-100 dark:bg-green-900/20 text-green-600 dark:text-green-400',
    purple:
      'bg-purple-100 dark:bg-purple-900/20 text-purple-600 dark:text-purple-400',
    orange:
      'bg-orange-100 dark:bg-orange-900/20 text-orange-600 dark:text-orange-400',
  };
  return colorMap[props.color] || colorMap.blue;
});

const progressPercentage = computed(() => {
  if (!props.limit) return 0;
  return Math.min(Math.round((props.current / props.limit) * 100), 100);
});

const progressBarClass = computed(() => {
  const percentage = progressPercentage.value;
  if (percentage >= 90) return 'bg-red-500';
  if (percentage >= 75) return 'bg-orange-500';
  if (percentage >= 50) return 'bg-yellow-500';
  return 'bg-green-500';
});

const remaining = computed(() => {
  if (!props.limit) return 0;
  return Math.max(props.limit - props.current, 0);
});

const isNearLimit = computed(() => {
  return props.limit && progressPercentage.value >= 75;
});

const usageText = computed(() => {
  if (!props.limit) return 'Unlimited usage';
  if (props.current >= props.limit) return 'Limit reached';
  return `${remaining.value} available`;
});
</script>

<template>
  <div
    class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6"
  >
    <div class="flex items-center justify-between mb-4">
      <div class="flex items-center space-x-3">
        <div class="p-2 rounded-lg" :class="iconBgClass">
          <i :class="iconClass" class="text-lg" />
        </div>
        <div>
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
            {{ title }}
          </h3>
          <p class="text-sm text-gray-500 dark:text-gray-400">
            {{ description }}
          </p>
        </div>
      </div>
      <div class="text-right">
        <div class="text-2xl font-bold text-gray-900 dark:text-white">
          {{ current
          }}<span class="text-sm font-normal text-gray-500">{{
            limit ? `/${limit}` : ''
          }}</span>
        </div>
        <div class="text-xs text-gray-500 dark:text-gray-400">
          {{ usageText }}
        </div>
      </div>
    </div>

    <!-- Progress Bar -->
    <div
      v-if="limit"
      class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2 mb-2"
    >
      <div
        class="h-2 rounded-full transition-all duration-300"
        :class="progressBarClass"
        :style="{ width: `${progressPercentage}%` }"
      />
    </div>

    <!-- Usage Status -->
    <div class="flex items-center justify-between text-xs">
      <span class="text-gray-500 dark:text-gray-400">
        {{
          limit
            ? `${progressPercentage}% ${$t('BILLING_SETTINGS.USED')}`
            : $t('BILLING_SETTINGS.UNLIMITED')
        }}
      </span>
      <span
        v-if="limit && isNearLimit"
        class="text-orange-600 dark:text-orange-400 font-medium"
      >
        {{ remaining }} {{ $t('BILLING_SETTINGS.REMAINING') }}
      </span>
    </div>
  </div>
</template>
