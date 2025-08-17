<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import FeatureToggle from 'dashboard/components/widgets/FeatureToggle.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

import InboxName from 'dashboard/components/widgets/InboxName.vue';
import { conversationUrl } from 'dashboard/helper/URLHelper.js';
import { useMapGetter } from 'dashboard/composables/store.js';
import ConversationModal from './ConversationModal.vue';

const store = useStore();
const router = useRouter();
const { t } = useI18n();
const stages = computed(() => store.getters['kanban/orderedStages']);
const rawCardsForStage = stageId =>
  store.getters['kanban/cardsForStage'](stageId);
const loadingForStage = stageId =>
  store.getters['kanban/loadingForStage'](stageId);
const hasMoreForStage = stageId =>
  store.getters['kanban/hasMoreForStage'](stageId);
const filters = computed(() => store.getters['kanban/filters']);

// Store getters
const accountId = useMapGetter('getCurrentAccountId');
const inboxesList = useMapGetter('inboxes/getInboxes');
const agentsList = useMapGetter('agents/getAgents');

const draggingCardId = ref(null);
const dragOverStageId = ref(null);
const dragOverCardId = ref(null);

// Filter refs
const selectedInbox = ref(null);
const selectedAssignee = ref(null);
const selectedLabels = ref([]);
const dateRange = ref({ start: null, end: null });

// Scroll refs
const stagesContainer = ref(null);
const canScrollLeft = ref(false);
const canScrollRight = ref(false);

// Modal refs
const showConversationModal = ref(false);
const selectedConversation = ref(null);

// ComboBox options
const inboxOptions = computed(() => [
  { value: null, label: `All ${t('KANBAN.BOARD.INBOX')}s` },
  ...inboxesList.value.map(inbox => ({
    value: inbox.id,
    label: inbox.name,
  })),
]);

const assigneeOptions = computed(() => [
  { value: null, label: `All ${t('KANBAN.BOARD.ASSIGNEE')}s` },
  ...agentsList.value.map(agent => ({
    value: agent.id,
    label: agent.name,
  })),
]);

const hasActiveFilters = computed(
  () =>
    Boolean((filters.value.q || '').trim()) ||
    selectedInbox.value ||
    selectedAssignee.value ||
    selectedLabels.value.length > 0 ||
    dateRange.value.start ||
    dateRange.value.end
);

const clearAllFilters = () => {
  store.dispatch('kanban/setFilter', {
    q: '',
    inbox_id: null,
    assignee_id: null,
    label_ids: [],
    created_after: null,
    created_before: null,
  });
  selectedInbox.value = null;
  selectedAssignee.value = null;
  selectedLabels.value = [];
  dateRange.value = { start: null, end: null };
};

// Scroll functions
const checkScrollButtons = () => {
  if (stagesContainer.value) {
    const container = stagesContainer.value;
    canScrollLeft.value = container.scrollLeft > 0;
    canScrollRight.value =
      container.scrollLeft < container.scrollWidth - container.clientWidth;
  }
};

onMounted(() => {
  store.dispatch('kanban/fetchInitial');
  // Load filter options
  store.dispatch('inboxes/get');
  store.dispatch('agents/get');

  // Setup scroll listeners
  if (stagesContainer.value) {
    stagesContainer.value.addEventListener('scroll', checkScrollButtons);
    checkScrollButtons();
  }
});

const updateFilters = () => {
  const newFilters = {
    q: filters.value.q || '',
    inbox_id: selectedInbox.value || null,
    assignee_id: selectedAssignee.value || null,
    label_ids: selectedLabels.value || [],
    created_after: dateRange.value.start || null,
    created_before: dateRange.value.end || null,
  };
  store.dispatch('kanban/setFilter', newFilters);
};

// Filter functions
const onInboxChange = inboxId => {
  selectedInbox.value = inboxId;
  updateFilters();
};

const onAssigneeChange = assigneeId => {
  selectedAssignee.value = assigneeId;
  updateFilters();
};

// Navigation function
const openConversation = card => {
  const url = conversationUrl({
    accountId: accountId.value,
    id: card.id,
  });
  router.push(`/app/${url}`);
};

// Modal functions
const openConversationModal = card => {
  selectedConversation.value = card;
  showConversationModal.value = true;
};

const closeConversationModal = () => {
  showConversationModal.value = false;
  selectedConversation.value = null;
};

const scrollLeft = () => {
  if (stagesContainer.value) {
    stagesContainer.value.scrollBy({
      left: -330, // Width of one stage + gap (300px + 30px gap)
      behavior: 'smooth',
    });
  }
};

const scrollRight = () => {
  if (stagesContainer.value) {
    stagesContainer.value.scrollBy({
      left: 330, // Width of one stage + gap (300px + 30px gap)
      behavior: 'smooth',
    });
  }
};

let scrollInterval = null;

const handleDragOver = e => {
  if (!stagesContainer.value) return;

  const containerRect = stagesContainer.value.getBoundingClientRect();
  const positionX = e.clientX;
  const deadZone = 150; // 150px from the edges

  // Stop any existing scroll interval
  if (scrollInterval) {
    clearInterval(scrollInterval);
    scrollInterval = null;
  }

  // Scroll left
  if (positionX < containerRect.left + deadZone) {
    scrollInterval = setInterval(() => {
      stagesContainer.value.scrollLeft -= 80; // Scroll speed
    }, 100); // Scroll interval
  }
  // Scroll right
  else if (positionX > containerRect.right - deadZone) {
    scrollInterval = setInterval(() => {
      stagesContainer.value.scrollLeft += 80; // Scroll speed
    }, 100); // Scroll interval
  }
};

const onDragStart = (e, card, stageId) => {
  draggingCardId.value = card.id;
  e.dataTransfer.setData('text/plain', String(card.id));
  e.dataTransfer.setData('fromStageId', String(stageId));
  e.dataTransfer.effectAllowed = 'move';

  // Add ghost image styling
  e.target.style.opacity = '0.5';
};

const onDragEnd = e => {
  draggingCardId.value = null;
  dragOverStageId.value = null;
  dragOverCardId.value = null;
  e.target.style.opacity = '';
  if (scrollInterval) {
    clearInterval(scrollInterval);
    scrollInterval = null;
  }
};

const onDrop = (e, stageId) => {
  e.preventDefault();
  const cardId = Number(e.dataTransfer.getData('text/plain'));
  if (!cardId) return;
  const fromStageId = Number(e.dataTransfer.getData('fromStageId'));

  if (fromStageId !== stageId) {
    store.dispatch('kanban/moveCard', {
      cardId,
      fromStageId,
      toStageId: stageId,
    });
  }

  dragOverStageId.value = null;
};

const onDragOver = (e, stageId) => {
  e.preventDefault();
  e.dataTransfer.dropEffect = 'move';
  dragOverStageId.value = stageId;
  handleDragOver(e);
};

const onDragLeave = e => {
  // Only clear if we're leaving the stage container entirely
  if (!e.currentTarget.contains(e.relatedTarget)) {
    dragOverStageId.value = null;
  }
};

const onColumnScroll = (e, stageId) => {
  const el = e.target;
  const ratio = el.scrollTop / (el.scrollHeight - el.clientHeight || 1);
  if (ratio > 0.85 && hasMoreForStage(stageId) && !loadingForStage(stageId)) {
    store.dispatch('kanban/loadMore', { stageId });
  }
};

const filteredCards = stageId => {
  const q = (filters.value.q || '').toLowerCase().trim();
  const list = rawCardsForStage(stageId);
  if (!q) return list;
  return list.filter(
    card =>
      String(card.contact_name || card.title || '')
        .toLowerCase()
        .includes(q) ||
      String(card.subject || '')
        .toLowerCase()
        .includes(q) ||
      String(card.assignee || '')
        .toLowerCase()
        .includes(q) ||
      (card.labels || []).some(l => String(l).toLowerCase().includes(q))
  );
};

const formatLastActivity = timestamp => {
  if (!timestamp) return '';
  const date = new Date(timestamp);
  const now = new Date();
  const diffInHours = (now - date) / (1000 * 60 * 60);

  if (diffInHours < 1) {
    return `${Math.floor(diffInHours * 60)}m ago`;
  }
  if (diffInHours < 24) {
    return `${Math.floor(diffInHours)}h ago`;
  }
  return `${Math.floor(diffInHours / 24)}d ago`;
};
</script>

<template>
  <FeatureToggle :feature-key="FEATURE_FLAGS.KANBAN">
    <div
      class="flex flex-col h-full w-full max-w-[calc(100vw-200px)] overflow-hidden bg-n-background"
    >
      <!-- Header / Filter bar - Fixed at top -->
      <div
        class="flex items-center justify-between w-full gap-2 border-b px-4 h-14 border-n-weak flex-shrink-0 bg-n-background/95 backdrop-blur-sm z-30"
      >
        <div class="flex items-center gap-4 min-w-0 flex-1">
          <h1 class="min-w-0 text-base font-medium truncate text-n-slate-12">
            {{ $t('KANBAN.BOARD.TITLE') }}
          </h1>
          <div class="flex items-center gap-2 overflow-x-auto">
            <!-- Active filter indicators -->
            <div
              v-if="hasActiveFilters"
              class="flex items-center gap-1 text-xs text-n-slate-11"
            >
              <Icon icon="i-lucide-filter" class="size-3" />
              <span>{{ $t('KANBAN.BOARD.FILTERS_ACTIVE') }}</span>
            </div>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <NextButton
            :label="$t('KANBAN.BOARD.REFRESH')"
            icon="i-lucide-rotate-cw"
            slate
            xs
            faded
            class="[&>.truncate]:hidden md:[&>.truncate]:block"
            @click="store.dispatch('kanban/fetchInitial')"
          />
          <router-link :to="{ name: 'kanban_settings_index' }">
            <NextButton
              :label="$t('KANBAN.BOARD.SETTINGS')"
              icon="i-lucide-sliders-horizontal"
              slate
              xs
              faded
              class="[&>.truncate]:hidden md:[&>.truncate]:block"
            />
          </router-link>
        </div>
      </div>

      <!-- Secondary filter row - Fixed below header -->
      <div
        class="border-b border-n-weak bg-n-background/95 backdrop-blur-sm z-20"
      >
        <div class="p-4">
          <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:gap-3">
            <!-- Search Input -->
            <div class="flex-1 min-w-0">
              <Input
                :model-value="filters.q"
                :placeholder="$t('KANBAN.BOARD.SEARCH')"
                class="w-full max-w-md"
                custom-input-class="!pl-9"
                @update:model-value="
                  val => store.dispatch('kanban/setFilter', { q: val })
                "
              >
                <template #prefix>
                  <div
                    class="pointer-events-none absolute ltr:left-3 rtl:right-3 top-1/2 -translate-y-1/2 text-n-slate-10"
                  >
                    <Icon icon="i-lucide-search" class="size-4" />
                  </div>
                </template>
              </Input>
            </div>

            <!-- Filter Controls -->
            <div class="flex flex-wrap gap-3 items-center">
              <!-- Inbox Filter -->
              <div class="min-w-[160px]">
                <ComboBox
                  :model-value="selectedInbox"
                  :options="inboxOptions"
                  :placeholder="$t('KANBAN.BOARD.INBOX')"
                  class="w-full"
                  @update:model-value="onInboxChange"
                />
              </div>

              <!-- Assignee Filter -->
              <div class="min-w-[160px]">
                <ComboBox
                  :model-value="selectedAssignee"
                  :options="assigneeOptions"
                  :placeholder="$t('KANBAN.BOARD.ASSIGNEE')"
                  class="w-full"
                  @update:model-value="onAssigneeChange"
                />
              </div>

              <!-- Clear Filters Button -->
              <NextButton
                v-if="hasActiveFilters"
                size="sm"
                variant="outline"
                color="slate"
                :label="$t('KANBAN.BOARD.CLEAR_FILTERS')"
                icon="i-lucide-x"
                @click="clearAllFilters"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Columns Container - Scrollable area below headers -->
      <div
        class="flex-1 h-full w-full overflow-x-hidden overflow-y-hidden relative bg-gradient-to-br from-n-background via-n-background to-n-alpha-2 max-w-full"
      >
        <!-- Scroll Left Button -->
        <button
          v-show="canScrollLeft"
          class="absolute left-2 top-1/2 transform -translate-y-1/2 z-10 bg-n-background border border-n-weak rounded-full p-2 shadow-lg hover:bg-n-alpha-2 transition-all duration-200 hover:scale-105 backdrop-blur-sm"
          @click="scrollLeft"
        >
          <Icon icon="i-lucide-chevron-left" class="size-5 text-n-slate-12" />
        </button>

        <!-- Scroll Right Button -->
        <button
          v-show="canScrollRight"
          class="absolute right-2 top-1/2 transform -translate-y-1/2 z-10 bg-n-background border border-n-weak rounded-full p-2 shadow-lg hover:bg-n-alpha-2 transition-all duration-200 hover:scale-105 backdrop-blur-sm"
          @click="scrollRight"
        >
          <Icon icon="i-lucide-chevron-right" class="size-5 text-n-slate-12" />
        </button>

        <!-- Scroll fade indicators -->
        <div
          class="absolute left-0 top-0 bottom-0 w-8 bg-gradient-to-r from-n-background/80 to-transparent z-10 pointer-events-none opacity-0 transition-opacity duration-300"
          :class="{ 'opacity-100': canScrollLeft }"
        />
        <div
          class="absolute right-0 top-0 bottom-0 w-8 bg-gradient-to-l from-n-background/80 to-transparent z-10 pointer-events-none opacity-0 transition-opacity duration-300"
          :class="{ 'opacity-100': canScrollRight }"
        />

        <div
          ref="stagesContainer"
          class="stages-container flex gap-6 p-6 h-full w-full scroll-smooth relative overflow-x-auto overflow-y-hidden"
          @scroll="checkScrollButtons"
        >
          <section
            v-for="stage in stages"
            :key="stage.id"
            class="min-w-[300px] w-[300px] max-w-[300px] flex flex-col border border-n-weak rounded-xl bg-n-background/80 backdrop-blur-sm shadow-sm hover:shadow-md transition-all duration-200 flex-shrink-0 hover:-translate-y-0.5"
            :class="{
              'ring-2 ring-n-brand/60 shadow-lg scale-[1.02] bg-n-brand/5':
                dragOverStageId === stage.id,
              'shadow-sm': dragOverStageId !== stage.id,
            }"
            @dragover="e => onDragOver(e, stage.id)"
            @dragleave="onDragLeave"
            @drop="e => onDrop(e, stage.id)"
          >
            <header
              class="sticky top-0 z-10 px-3 py-2 border-b border-n-weak border-t-2 flex items-center justify-between backdrop-blur bg-n-background/60"
              :style="{ borderTopColor: stage.color }"
            >
              <div class="flex items-center gap-2">
                <span
                  class="inline-block size-2 rounded-sm"
                  :style="{ backgroundColor: stage.color }"
                />
                <h3 class="font-medium text-sm text-n-slate-12">
                  {{ stage.name }}
                </h3>
              </div>
              <span
                class="text-xs text-n-slate-11 rounded-full px-2 py-0.5 bg-n-alpha-black2"
              >
                {{ stage.count }}
              </span>
            </header>

            <ul
              role="list"
              class="flex-1 overflow-y-auto p-2 space-y-2 scroll-smooth max-h-[calc(100vh-200px)]"
              @scroll="e => onColumnScroll(e, stage.id)"
            >
              <!-- Cards -->
              <li
                v-for="card in filteredCards(stage.id)"
                :key="card.id"
                class="p-3 rounded-lg border border-n-weak bg-n-background cursor-grab group transition-all duration-200 ease-out hover:shadow-lg hover:-translate-y-1 hover:border-n-brand/30 relative [&:active]:cursor-grabbing"
                :class="{
                  'opacity-50 scale-95 rotate-2 shadow-xl ring-2 ring-n-brand/50':
                    draggingCardId === card.id,
                  'cursor-grabbing': draggingCardId === card.id,
                }"
                draggable="true"
                role="listitem"
                :aria-grabbed="draggingCardId === card.id ? 'true' : 'false'"
                @dragstart="e => onDragStart(e, card, stage.id)"
                @dragend="onDragEnd"
                @click="openConversationModal(card)"
              >
                <!-- Open Conversation Button -->
                <button
                  class="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity bg-n-brand text-white rounded-full p-1 hover:bg-n-brand-dark hover:scale-105 z-10"
                  :title="$t('KANBAN.BOARD.OPEN_CONVERSATION')"
                  @click.stop="openConversation(card)"
                >
                  <Icon icon="i-lucide-external-link" class="size-3" />
                </button>

                <div class="flex items-start gap-3">
                  <div class="relative">
                    <Avatar
                      :name="card.contact_name || card.title"
                      :size="32"
                      rounded-full
                      class="mt-1"
                    />
                    <span
                      v-if="card.status === 'open'"
                      class="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 bg-n-teal-10 border-2 border-white rounded-full"
                      :title="$t('CONVERSATION.STATUS.OPEN')"
                    />
                    <span
                      v-else-if="card.status === 'pending'"
                      class="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 bg-n-amber-9 border-2 border-white rounded-full"
                      :title="$t('CONVERSATION.STATUS.PENDING')"
                    />
                    <span
                      v-else-if="card.status === 'resolved'"
                      class="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 bg-n-green-10 border-2 border-white rounded-full"
                      :title="$t('CONVERSATION.STATUS.RESOLVED')"
                    />
                  </div>
                  <div class="min-w-0 flex-1">
                    <!-- Header with name and unread count -->
                    <div class="flex items-start justify-between mb-1">
                      <div class="min-w-0 flex-1">
                        <p
                          class="text-sm font-medium truncate text-n-slate-12 leading-5"
                        >
                          {{ card.contact_name || card.title }}
                        </p>
                        <!-- Contact info - coalesced phone/email -->
                        <div
                          v-if="card.contact_phone || card.contact_email"
                          class="flex items-center gap-2 mt-1"
                        >
                          <span
                            v-if="card.contact_phone"
                            class="text-[10px] text-n-slate-10 flex items-center gap-1"
                          >
                            <Icon icon="i-lucide-phone" class="size-3" />
                            {{ card.contact_phone }}
                          </span>
                          <span
                            v-else-if="card.contact_email"
                            class="text-[10px] text-n-slate-10 flex items-center gap-1"
                          >
                            <Icon icon="i-lucide-mail" class="size-3" />
                            {{ card.contact_email }}
                          </span>
                        </div>
                      </div>
                      <span
                        v-if="card.unread_count && card.unread_count > 0"
                        class="inline-flex items-center justify-center rounded-full bg-n-ruby-9 text-white text-[10px] px-1.5 py-0.5 font-medium ml-2 flex-shrink-0"
                        :aria-label="
                          $t('CONVERSATION.UNREAD_COUNT', {
                            count: card.unread_count,
                          })
                        "
                      >
                        {{ card.unread_count }}
                      </span>
                    </div>

                    <!-- Message preview -->
                    <p
                      class="text-xs text-n-slate-11 truncate mb-2 leading-4 [display:-webkit-box] [-webkit-line-clamp:2] [-webkit-box-orient:vertical] overflow-hidden [word-break:break-word]"
                    >
                      {{ card.subject || card.last_message || card.title }}
                    </p>

                    <!-- Labels -->
                    <div
                      v-if="card.labels && card.labels.length > 0"
                      class="flex flex-wrap gap-1 mb-2"
                    >
                      <span
                        v-for="label in (card.labels || []).slice(0, 3)"
                        :key="label.id || label"
                        class="px-1.5 py-0.5 rounded text-[10px] text-white"
                        :style="{ backgroundColor: label.color || '#6366f1' }"
                      >
                        {{ label.title || label }}
                      </span>
                      <span
                        v-if="(card.labels || []).length > 3"
                        class="px-1.5 py-0.5 rounded bg-n-slate-3 text-n-slate-11 text-[10px]"
                      >
                        +{{ (card.labels || []).length - 3 }}
                      </span>
                    </div>

                    <!-- Footer with assignee, inbox, and timestamp -->
                    <div
                      class="flex items-center justify-between text-[10px] text-n-slate-10"
                    >
                      <div class="flex items-center gap-2 min-w-0 flex-1">
                        <div
                          v-if="card.assignee"
                          class="flex items-center gap-1"
                        >
                          <Icon icon="i-lucide-user" class="size-3" />
                          <span class="truncate">{{
                            card.assignee.name || card.assignee
                          }}</span>
                        </div>
                        <div
                          v-if="card.assignee && card.inbox"
                          class="w-px h-3 bg-n-slate-4"
                        />
                        <InboxName
                          v-if="card.inbox"
                          :inbox="card.inbox"
                          class="text-[10px]"
                        />
                      </div>
                      <span
                        class="text-[10px] text-n-slate-10 ml-2 flex-shrink-0"
                      >
                        {{ formatLastActivity(card.updated_at) }}
                      </span>
                    </div>
                  </div>
                  <Icon
                    icon="i-lucide-grip-vertical"
                    class="opacity-0 group-hover:opacity-100 transition-opacity size-4 flex-none text-n-slate-10 cursor-grab mt-1 [&:active]:cursor-grabbing"
                    :class="{ 'cursor-grabbing': draggingCardId === card.id }"
                    :aria-label="$t('KANBAN.BOARD.DRAG_HANDLE_LABEL')"
                    aria-hidden="true"
                  />
                </div>
              </li>

              <!-- Infinite scroll loading indicator -->
              <template v-if="loadingForStage(stage.id)">
                <li
                  v-for="n in 3"
                  :key="`s-${n}`"
                  class="p-3 rounded-lg border border-n-weak bg-n-background animate-pulse"
                >
                  <div class="flex items-start gap-3">
                    <div class="w-7 h-7 bg-n-slate-3 rounded-full mt-1" />
                    <div class="flex-1">
                      <div class="h-4 w-2/3 bg-n-slate-3 rounded mb-2" />
                      <div class="h-3 w-1/2 bg-n-slate-3 rounded mb-2" />
                      <div class="flex items-center gap-2 h-6">
                        <div class="h-4 w-12 bg-n-slate-3 rounded" />
                        <div class="h-4 w-8 bg-n-slate-3 rounded" />
                        <div class="h-3 w-16 bg-n-slate-3 rounded ml-auto" />
                      </div>
                    </div>
                  </div>
                </li>
              </template>

              <!-- End of list indicator -->
              <li
                v-if="
                  !hasMoreForStage(stage.id) &&
                  !loadingForStage(stage.id) &&
                  filteredCards(stage.id).length > 0
                "
                class="text-center py-4 text-xs text-n-slate-10"
              >
                {{ $t('KANBAN.BOARD.END_OF_LIST') }}
              </li>
            </ul>
          </section>
        </div>
      </div>
    </div>

    <!-- Conversation Modal -->
    <ConversationModal
      :show="showConversationModal"
      :conversation="selectedConversation"
      @close="closeConversationModal"
    />
  </FeatureToggle>
</template>
