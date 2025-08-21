<script>
import ScheduledMessageApi from 'dashboard/api/inbox/scheduledMessage';

export default {
  name: 'ScheduledMessagesList',
  props: {
    conversationId: { type: Number, required: true },
  },
  data() {
    return { items: [], loading: false };
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      try {
        this.loading = true;
        const { data } = await ScheduledMessageApi.list({ conversationId: this.conversationId });
        this.items = data.payload || [];
      } finally {
        this.loading = false;
      }
    },
    async cancel(id) {
      await ScheduledMessageApi.cancel({ conversationId: this.conversationId, id });
      this.items = this.items.filter(i => i.id !== id);
      this.$emit('cancelled', id);
    },
  },
};
</script>

<template>
  <div v-if="items.length" class="px-4 py-2">
    <div class="text-xs text-n-slate-11 mb-1">
      {{ $t('CONVERSATION.FOOTER.SCHEDULED_MESSAGES') }}
    </div>
    <ul class="flex flex-col gap-1">
      <li v-for="item in items" :key="item.id" class="flex items-center justify-between bg-n-solid-1 border border-n-weak rounded px-2 py-1">
        <div class="text-xs text-n-slate-12">
          📅 {{ new Date(item.scheduled_at).toLocaleString() }} — {{ item.content }}
        </div>
        <button class="text-xs text-red-500 hover:text-red-600" @click="cancel(item.id)">
          {{ $t('CONVERSATION.FOOTER.CANCEL_SCHEDULE') }}
        </button>
      </li>
    </ul>
  </div>
</template>

