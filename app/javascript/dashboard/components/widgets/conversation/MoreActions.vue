<script setup>
import { computed, onMounted, onUnmounted } from 'vue';
import { useToggle } from '@vueuse/core';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { emitter } from 'shared/helpers/mitt';
import EmailTranscriptModal from './EmailTranscriptModal.vue';
import ResolveAction from '../../buttons/ResolveAction.vue';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

import {
  CMD_MUTE_CONVERSATION,
  CMD_SEND_TRANSCRIPT,
  CMD_UNMUTE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

// No props needed as we're getting currentChat from the store directly
const store = useStore();
const { t } = useI18n();

const [showEmailActionsModal, toggleEmailModal] = useToggle(false);
const [showActionsDropdown, toggleDropdown] = useToggle(false);
const [showStageDropdown, toggleStageDropdown] = useToggle(false);

const currentChat = computed(() => store.getters.getSelectedChat);

// Kanban stages for stage dropdown
const kanbanStages = computed(
  () => store.getters['kanban/orderedStages'] || []
);
const currentStageId = computed(() => currentChat.value?.kanban_stage_id);

const stageOptions = computed(() =>
  kanbanStages.value.map(stage => ({
    value: stage.id,
    label: stage.name,
  }))
);

const actionMenuItems = computed(() => {
  const items = [];

  if (!currentChat.value.muted) {
    items.push({
      icon: 'i-lucide-volume-off',
      label: t('CONTACT_PANEL.MUTE_CONTACT'),
      action: 'mute',
      value: 'mute',
    });
  } else {
    items.push({
      icon: 'i-lucide-volume-1',
      label: t('CONTACT_PANEL.UNMUTE_CONTACT'),
      action: 'unmute',
      value: 'unmute',
    });
  }

  items.push({
    icon: 'i-lucide-share',
    label: t('CONTACT_PANEL.SEND_TRANSCRIPT'),
    action: 'send_transcript',
    value: 'send_transcript',
  });

  // Add change stage action if kanban stages are available
  if (kanbanStages.value.length > 0) {
    items.push({
      icon: 'i-lucide-columns-2',
      label: t('KANBAN.BOARD.CHANGE_STAGE'),
      action: 'change_stage',
      value: 'change_stage',
    });
  }

  return items;
});

const handleActionClick = ({ action }) => {
  toggleDropdown(false);

  if (action === 'mute') {
    store.dispatch('muteConversation', currentChat.value.id);
    useAlert(t('CONTACT_PANEL.MUTED_SUCCESS'));
  } else if (action === 'unmute') {
    store.dispatch('unmuteConversation', currentChat.value.id);
    useAlert(t('CONTACT_PANEL.UNMUTED_SUCCESS'));
  } else if (action === 'send_transcript') {
    toggleEmailModal();
  } else if (action === 'change_stage') {
    toggleStageDropdown();
  }
};

const handleStageChange = async stageId => {
  if (stageId !== currentStageId.value) {
    try {
      await store.dispatch('kanban/moveCard', {
        cardId: currentChat.value.id,
        fromStageId: currentStageId.value,
        toStageId: stageId,
      });
      useAlert(t('KANBAN.BOARD.STAGE_CHANGED_SUCCESS'));
    } catch (error) {
      useAlert(t('KANBAN.BOARD.STAGE_CHANGED_ERROR'));
    }
  }
  toggleStageDropdown(false);
};

// These functions are needed for the event listeners
const mute = () => {
  store.dispatch('muteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.MUTED_SUCCESS'));
};

const unmute = () => {
  store.dispatch('unmuteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.UNMUTED_SUCCESS'));
};

// Load kanban stages when component mounts
onMounted(() => {
  store.dispatch('kanban/fetchInitial').catch(() => {
    // Ignore errors when fetching kanban data - component should still work
  });
});

emitter.on(CMD_MUTE_CONVERSATION, mute);
emitter.on(CMD_UNMUTE_CONVERSATION, unmute);
emitter.on(CMD_SEND_TRANSCRIPT, toggleEmailModal);

onUnmounted(() => {
  emitter.off(CMD_MUTE_CONVERSATION, mute);
  emitter.off(CMD_UNMUTE_CONVERSATION, unmute);
  emitter.off(CMD_SEND_TRANSCRIPT, toggleEmailModal);
});
</script>

<template>
  <div class="relative flex items-center gap-2 actions--container">
    <ResolveAction
      :conversation-id="currentChat.id"
      :status="currentChat.status"
    />
    <div
      v-on-clickaway="() => toggleDropdown(false)"
      class="relative flex items-center group"
    >
      <ButtonV4
        v-tooltip="$t('CONVERSATION.HEADER.MORE_ACTIONS')"
        size="sm"
        variant="ghost"
        color="slate"
        icon="i-lucide-more-vertical"
        class="rounded-md group-hover:bg-n-alpha-2"
        @click="toggleDropdown()"
      />
      <DropdownMenu
        v-if="showActionsDropdown"
        :menu-items="actionMenuItems"
        class="mt-1 ltr:right-0 rtl:left-0 top-full"
        @action="handleActionClick"
      />
    </div>

    <!-- Stage Change Dropdown -->
    <div
      v-if="showStageDropdown"
      v-on-clickaway="() => toggleStageDropdown(false)"
      class="relative flex items-center"
    >
      <div class="absolute mt-1 ltr:right-0 rtl:left-0 top-full z-50 min-w-48">
        <div
          class="bg-n-background border border-n-weak rounded-lg shadow-lg p-2"
        >
          <div class="text-xs text-n-slate-11 mb-2 px-2">
            {{ $t('KANBAN.BOARD.SELECT_STAGE') }}
          </div>
          <ComboBox
            :model-value="currentStageId"
            :options="stageOptions"
            :placeholder="$t('KANBAN.BOARD.SELECT_STAGE')"
            class="w-full"
            @update:model-value="handleStageChange"
          />
        </div>
      </div>
    </div>
    <EmailTranscriptModal
      v-if="showEmailActionsModal"
      :show="showEmailActionsModal"
      :current-chat="currentChat"
      @cancel="toggleEmailModal"
    />
  </div>
</template>
