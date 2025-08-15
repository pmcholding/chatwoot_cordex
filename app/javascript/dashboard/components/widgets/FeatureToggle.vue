<script>
import { usePolicy } from 'dashboard/composables/usePolicy';
export default {
  props: {
    featureKey: {
      type: String,
      required: true,
    },
  },
  setup(props) {
    const { isFeatureFlagEnabled } = usePolicy();
    const isEnabled = isFeatureFlagEnabled(props.featureKey);
    return { isEnabled };
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <div v-if="isEnabled">
    <slot />
  </div>
</template>
