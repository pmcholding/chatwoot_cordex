<script setup>
import { computed, onMounted } from 'vue';
import { format } from 'date-fns';
import { useStore } from 'dashboard/composables/store.js';
import { useAccount } from 'dashboard/composables/useAccount';
import { useCaptain } from 'dashboard/composables/useCaptain';
import { useMapGetter } from 'dashboard/composables/store';

import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import BillingHeader from './components/BillingHeader.vue';
import ButtonV4 from 'next/button/Button.vue';
import CurrentPlanCard from './components/CurrentPlanCard.vue';
import UsageLimitCard from './components/UsageLimitCard.vue';

const store = useStore();
const { currentAccount } = useAccount();
const { captainEnabled, fetchLimits } = useCaptain();

const uiFlags = useMapGetter('accounts/getUIFlags');

// Account data from store
const planName = computed(
  () => currentAccount.value?.custom_attributes?.plan_name
);
const subscribedQuantity = computed(
  () => currentAccount.value?.custom_attributes?.subscribed_quantity
);
const subscriptionStatus = computed(
  () => currentAccount.value?.custom_attributes?.subscription_status
);
const subscriptionEndsOn = computed(
  () => currentAccount.value?.custom_attributes?.subscription_ends_on
);

// Account limits from the new metadata-based system
const accountLimits = computed(() => currentAccount.value?.limits || {});

// Usage data
const currentUsage = computed(() => ({
  inboxes: currentAccount.value?.inboxes?.length || 0,
  agents:
    currentAccount.value?.users?.filter(user => user.role === 'agent')
      ?.length || 0,
  captain_responses:
    currentAccount.value?.custom_attributes?.captain_responses_usage || 0,
  captain_documents:
    currentAccount.value?.custom_attributes?.captain_documents_usage || 0,
}));

// Formatted renewal date
const renewalDate = computed(() => {
  if (!subscriptionEndsOn.value) return null;
  const endDate = new Date(subscriptionEndsOn.value);
  return format(endDate, 'dd MMM, yyyy');
});

// Check if user has a billing plan
const hasABillingPlan = computed(() => {
  return !!planName.value;
});

// Check if using new metadata-based limits
const hasMetadataLimits = computed(() => {
  return Object.keys(accountLimits.value).length > 0;
});

const fetchAccountDetails = async () => {
  if (!hasABillingPlan.value) {
    store.dispatch('accounts/subscription');
    fetchLimits();
  }
};

const onManageSubscription = () => {
  store.dispatch('accounts/checkout');
};

const onViewPricing = () => {
  // Open pricing page or external link
  window.open('https://www.chatwoot.com/pricing', '_blank');
};

const onToggleChatWindow = () => {
  if (window.$chatwoot) {
    window.$chatwoot.toggle();
  }
};

onMounted(fetchAccountDetails);
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetchingItem"
    :loading-message="$t('ATTRIBUTES_MGMT.LOADING')"
    :no-records-found="!hasABillingPlan"
    :no-records-message="$t('BILLING_SETTINGS.NO_BILLING_USER')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('BILLING_SETTINGS.TITLE')"
        :description="$t('BILLING_SETTINGS.DESCRIPTION')"
        :link-text="$t('BILLING_SETTINGS.VIEW_PRICING')"
        feature-name="billing"
      />
    </template>

    <template #body>
      <div class="space-y-6">
        <!-- Current Plan Overview -->
        <CurrentPlanCard
          :plan-name="planName"
          :subscribed-quantity="subscribedQuantity"
          :renewal-date="renewalDate"
          :subscription-status="subscriptionStatus"
          :is-loading="uiFlags.isCheckoutInProcess"
          @manage-subscription="onManageSubscription"
          @view-pricing="onViewPricing"
        />

        <!-- Usage Limits Grid -->
        <div v-if="hasMetadataLimits" class="space-y-4">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
            {{ $t('BILLING_SETTINGS.USAGE_LIMITS.TITLE') }}
          </h3>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <!-- Inboxes -->
            <UsageLimitCard
              :title="$t('BILLING_SETTINGS.USAGE_LIMITS.INBOXES')"
              :description="$t('BILLING_SETTINGS.USAGE_LIMITS.INBOXES_DESC')"
              :current="currentUsage.inboxes"
              :limit="accountLimits.inboxes"
              icon="inbox"
              color="blue"
            />

            <!-- Agents -->
            <UsageLimitCard
              :title="$t('BILLING_SETTINGS.USAGE_LIMITS.AGENTS')"
              :description="$t('BILLING_SETTINGS.USAGE_LIMITS.AGENTS_DESC')"
              :current="currentUsage.agents"
              :limit="accountLimits.agents"
              icon="users"
              color="green"
            />

            <!-- Captain Responses -->
            <UsageLimitCard
              v-if="captainEnabled"
              :title="$t('BILLING_SETTINGS.USAGE_LIMITS.CAPTAIN_RESPONSES')"
              :description="
                $t('BILLING_SETTINGS.USAGE_LIMITS.CAPTAIN_RESPONSES_DESC')
              "
              :current="currentUsage.captain_responses"
              :limit="accountLimits.captain_responses"
              icon="robot"
              color="purple"
            />

            <!-- Captain Documents -->
            <UsageLimitCard
              v-if="captainEnabled"
              :title="$t('BILLING_SETTINGS.USAGE_LIMITS.CAPTAIN_DOCUMENTS')"
              :description="
                $t('BILLING_SETTINGS.USAGE_LIMITS.CAPTAIN_DOCUMENTS_DESC')
              "
              :current="currentUsage.captain_documents"
              :limit="accountLimits.captain_documents"
              icon="documents"
              color="orange"
            />
          </div>
        </div>

        <!-- Legacy Captain Section (for accounts without metadata) -->
        <div v-else-if="captainEnabled" class="space-y-4">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
            {{ $t('BILLING_SETTINGS.CAPTAIN.TITLE') }}
          </h3>

          <div
            class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6"
          >
            <div class="flex items-center justify-between mb-4">
              <div>
                <h4 class="text-lg font-medium text-gray-900 dark:text-white">
                  {{ $t('BILLING_SETTINGS.CAPTAIN.TITLE') }}
                </h4>
                <p class="text-gray-600 dark:text-gray-400">
                  {{ $t('BILLING_SETTINGS.CAPTAIN.DESCRIPTION') }}
                </p>
              </div>
              <ButtonV4 sm faded slate @click="onManageSubscription">
                {{ $t('BILLING_SETTINGS.CAPTAIN.BUTTON_TXT') }}
              </ButtonV4>
            </div>
          </div>
        </div>

        <!-- Support Section -->
        <BillingHeader
          class="px-1 mt-8"
          :title="$t('BILLING_SETTINGS.CHAT_WITH_US.TITLE')"
          :description="$t('BILLING_SETTINGS.CHAT_WITH_US.DESCRIPTION')"
        >
          <ButtonV4
            sm
            solid
            slate
            icon="i-lucide-life-buoy"
            @click="onToggleChatWindow"
          >
            {{ $t('BILLING_SETTINGS.CHAT_WITH_US.BUTTON_TXT') }}
          </ButtonV4>
        </BillingHeader>
      </div>
    </template>
  </SettingsLayout>
</template>
