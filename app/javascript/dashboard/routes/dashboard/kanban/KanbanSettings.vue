<script setup>
import FeatureToggle from 'dashboard/components/widgets/FeatureToggle.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
</script>

<template>
  <FeatureToggle :feature-key="FEATURE_FLAGS.KANBAN">
    <div class="p-4 space-y-3">
      <h1 class="text-xl font-semibold">{{ $t('KANBAN.SETTINGS.TITLE') }}</h1>
      <div class="text-sm text-gray-600">
        Mock de configurações: aqui teremos lista de estágios, criação/edição/remoção e reorder.
      </div>
    </div>
  </FeatureToggle>
</template>

