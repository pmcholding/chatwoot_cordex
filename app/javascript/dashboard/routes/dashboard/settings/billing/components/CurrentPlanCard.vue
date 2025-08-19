<script setup>
import { computed } from 'vue';
import ButtonV4 from 'next/button/Button.vue';

const props = defineProps({
  planName: {
    type: String,
    default: null,
  },
  subscribedQuantity: {
    type: [Number, String],
    default: null,
  },
  renewalDate: {
    type: String,
    default: null,
  },
  subscriptionStatus: {
    type: String,
    default: null,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['manageSubscription', 'viewPricing']);

const statusText = computed(() => {
  const status = props.subscriptionStatus?.toLowerCase();
  const statusMap = {
    active: 'Ativo',
    trialing: 'Período de Teste',
    past_due: 'Pagamento Pendente',
    canceled: 'Cancelado',
    unpaid: 'Não Pago',
    incomplete: 'Incompleto',
  };
  return statusMap[status] || 'Desconhecido';
});

const statusBadgeClass = computed(() => {
  const status = props.subscriptionStatus?.toLowerCase();
  const classMap = {
    active:
      'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400',
    trialing:
      'bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400',
    past_due:
      'bg-orange-100 text-orange-800 dark:bg-orange-900/20 dark:text-orange-400',
    canceled: 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400',
    unpaid: 'bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400',
    incomplete:
      'bg-gray-100 text-gray-800 dark:bg-gray-900/20 dark:text-gray-400',
  };
  return (
    classMap[status] ||
    'bg-gray-100 text-gray-800 dark:bg-gray-900/20 dark:text-gray-400'
  );
});

const statusDotClass = computed(() => {
  const status = props.subscriptionStatus?.toLowerCase();
  const classMap = {
    active: 'bg-green-500',
    trialing: 'bg-blue-500',
    past_due: 'bg-orange-500',
    canceled: 'bg-red-500',
    unpaid: 'bg-red-500',
    incomplete: 'bg-gray-500',
  };
  return classMap[status] || 'bg-gray-500';
});

const statusTextClass = computed(() => {
  const status = props.subscriptionStatus?.toLowerCase();
  const classMap = {
    active: 'text-green-600 dark:text-green-400',
    trialing: 'text-blue-600 dark:text-blue-400',
    past_due: 'text-orange-600 dark:text-orange-400',
    canceled: 'text-red-600 dark:text-red-400',
    unpaid: 'text-red-600 dark:text-red-400',
    incomplete: 'text-gray-600 dark:text-gray-400',
  };
  return classMap[status] || 'text-gray-600 dark:text-gray-400';
});

const onManageSubscription = () => {
  emit('manageSubscription');
};

const onViewPricing = () => {
  emit('viewPricing');
};
</script>

<template>
  <div
    class="bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 rounded-lg border border-blue-200 dark:border-blue-800 p-6"
  >
    <div class="flex items-center justify-between mb-6">
      <div>
        <h2 class="text-2xl font-bold text-gray-900 dark:text-white mb-2">
          {{ planName || $t('BILLING_SETTINGS.CURRENT_PLAN') }}
        </h2>
        <p class="text-gray-600 dark:text-gray-300">
          {{ $t('BILLING_SETTINGS.CURRENT_PLAN_DESC') }}
        </p>
      </div>
      <div class="text-right">
        <div
          class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium"
          :class="statusBadgeClass"
        >
          <div class="w-2 h-2 rounded-full mr-2" :class="statusDotClass" />
          {{ statusText }}
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
      <div
        class="text-center p-4 bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700"
      >
        <div class="text-sm text-gray-500 dark:text-gray-400 mb-1">
          {{ $t('BILLING_SETTINGS.USERS') }}
        </div>
        <div class="text-xl font-semibold text-gray-900 dark:text-white">
          {{ subscribedQuantity || '-' }}
        </div>
      </div>

      <div
        class="text-center p-4 bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700"
      >
        <div class="text-sm text-gray-500 dark:text-gray-400 mb-1">
          {{ $t('BILLING_SETTINGS.NEXT_BILLING') }}
        </div>
        <div class="text-xl font-semibold text-gray-900 dark:text-white">
          {{ renewalDate || '-' }}
        </div>
      </div>

      <div
        class="text-center p-4 bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700"
      >
        <div class="text-sm text-gray-500 dark:text-gray-400 mb-1">
          {{ $t('BILLING_SETTINGS.STATUS') }}
        </div>
        <div class="text-xl font-semibold" :class="statusTextClass">
          {{ subscriptionStatus || '-' }}
        </div>
      </div>
    </div>

    <div class="flex flex-col sm:flex-row gap-3">
      <ButtonV4
        solid
        blue
        class="flex-1"
        :loading="isLoading"
        @click="onManageSubscription"
      >
        <i class="i-lucide-credit-card mr-2" />
        {{ $t('BILLING_SETTINGS.MANAGE_SUBSCRIPTION.BUTTON_TXT') }}
      </ButtonV4>

      <ButtonV4 faded slate @click="onViewPricing">
        <i class="i-lucide-eye mr-2" />
        {{ $t('BILLING_SETTINGS.VIEW_PLANS') }}
      </ButtonV4>
    </div>
  </div>
</template>
