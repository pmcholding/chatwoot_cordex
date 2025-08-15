<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import FeatureToggle from 'dashboard/components/widgets/FeatureToggle.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

const route = useRoute();
const store = useStore();

const accountId = computed(() => store.getters.getCurrentAccountId);
</script>

<template>
  <FeatureToggle :feature-key="FEATURE_FLAGS.KANBAN">
    <div class="h-full w-full flex flex-col">
      <div class="p-4 border-b">
        <h1 class="text-xl font-medium">
          {{ $t('KANBAN.PLACEHOLDER.TITLE') }}
        </h1>
        <p class="text-sm text-gray-600">
          {{ $t('KANBAN.PLACEHOLDER.ACCOUNT') }} {{ accountId }}
        </p>
        <p class="text-sm text-gray-600">
          {{ $t('KANBAN.PLACEHOLDER.ROUTE') }} {{ route.fullPath }}
        </p>
      </div>
      <div class="flex-1 grid place-content-center text-gray-500">
        <div class="text-center space-y-2">
          <div class="text-5xl">{{ $t('KANBAN.PLACEHOLDER.EMOJI') }}</div>
          <p>{{ $t('KANBAN.PLACEHOLDER.BODY') }}</p>
          <p class="text-xs">{{ $t('KANBAN.PLACEHOLDER.FOOTER') }}</p>
        </div>
      </div>
      <router-link
        class="fixed bottom-4 right-4 text-xs underline text-blue-600"
        :to="{ name: 'inbox_view' }"
      >
        {{ $t('KANBAN.PLACEHOLDER.BACK') }}
      </router-link>
    </div>
  </FeatureToggle>
</template>
