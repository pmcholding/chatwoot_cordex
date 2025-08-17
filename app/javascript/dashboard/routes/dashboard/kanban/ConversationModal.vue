<script setup>
import { watch, onMounted } from 'vue';
import { useStore } from 'vuex';
import ConversationBox from 'dashboard/components/widgets/conversation/ConversationBox.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  conversation: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close']);

const store = useStore();

watch(
  () => props.conversation,
  newConversation => {
    if (newConversation) {
      store.dispatch('setActiveChat', { data: newConversation });
      store.dispatch('fetchPreviousMessages', {
        conversationId: newConversation.id,
        before: null,
      });
      store.dispatch('fetchAllAttachments', newConversation.id);
    } else {
      store.dispatch('clearSelectedState');
    }
  }
);

onMounted(() => {
  if (props.conversation) {
    store.dispatch('setActiveChat', { data: props.conversation });
    store.dispatch('fetchPreviousMessages', {
      conversationId: props.conversation.id,
      before: null,
    });
    store.dispatch('fetchAllAttachments', props.conversation.id);
  }
});
</script>

<template>
  <div
    v-if="show"
    class="fixed inset-0 z-50 flex items-center justify-center bg-modal-backdrop-light dark:bg-modal-backdrop-dark"
    @click.self="emit('close')"
  >
    <div
      class="w-full max-w-6xl h-full max-h-[90vh] bg-n-background rounded-lg shadow-xl overflow-hidden flex flex-col"
    >
      <div
        class="flex items-center justify-between p-4 border-b border-n-weak flex-shrink-0"
      >
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{
            $t('KANBAN.MODAL.TITLE', {
              contactName: conversation?.meta?.sender?.name,
            })
          }}
        </h2>
        <button
          class="p-2 rounded-lg hover:bg-n-alpha-2 transition-colors"
          @click="emit('close')"
        >
          <i class="fluent-icon icon-dismiss" />
        </button>
      </div>
      <div class="flex-grow min-h-0">
        <ConversationBox
          v-if="conversation"
          :inbox-id="conversation.inbox_id"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.conversation-details-wrap {
  height: calc(90vh - 80px);
}

.conversation-panel {
  scrollbar-width: thin;
  scrollbar-color: rgb(var(--n-slate-6)) rgb(var(--n-slate-2));
}

.conversation-panel::-webkit-scrollbar {
  width: 6px;
}

.conversation-panel::-webkit-scrollbar-track {
  background-color: rgb(var(--n-slate-2));
}

.conversation-panel::-webkit-scrollbar-thumb {
  background-color: rgb(var(--n-slate-6));
  border-radius: 4px;
}

.prose-bubble p {
  margin: 0;
  line-height: 1.5;
}

.reply-box {
  border-top: 1px solid rgb(var(--n-weak));
}
</style>
