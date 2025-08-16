<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import FeatureToggle from 'dashboard/components/widgets/FeatureToggle.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

import InboxName from 'dashboard/components/widgets/InboxName.vue';
import { conversationUrl } from 'dashboard/helper/URLHelper.js';
import { useMapGetter } from 'dashboard/composables/store.js';
import ConversationModal from './ConversationModal.vue';

const store = useStore();
const router = useRouter();
const stages = computed(() => store.getters['kanban/orderedStages']);
const rawCardsForStage = stageId => store.getters['kanban/cardsForStage'](stageId);
const loadingForStage = stageId => store.getters['kanban/loadingForStage'](stageId);
const hasMoreForStage = stageId => store.getters['kanban/hasMoreForStage'](stageId);
const filters = computed(() => store.getters['kanban/filters']);

// Store getters
const accountId = useMapGetter('getCurrentAccountId');
const inboxesList = useMapGetter('inboxes/getInboxes');
const agentsList = useMapGetter('agents/getAgents');
const labelsList = useMapGetter('labels/getLabels');

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

const hasActiveFilters = computed(() =>
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
    created_before: null
  });
  selectedInbox.value = null;
  selectedAssignee.value = null;
  selectedLabels.value = [];
  dateRange.value = { start: null, end: null };
};

onMounted(() => {
  store.dispatch('kanban/fetchInitial');
  // Load filter options
  store.dispatch('inboxes/get');
  store.dispatch('agents/get');
  store.dispatch('labels/get');

  // Setup scroll listeners
  if (stagesContainer.value) {
    stagesContainer.value.addEventListener('scroll', checkScrollButtons);
    checkScrollButtons();
  }
});

const updateFilters = () => {
  const newFilters = {
    q: filters.value.q || '',
    inbox_id: selectedInbox.value?.id || null,
    assignee_id: selectedAssignee.value?.id || null,
    label_ids: selectedLabels.value.map(l => l.id) || [],
    created_after: dateRange.value.start || null,
    created_before: dateRange.value.end || null,
  };
  store.dispatch('kanban/setFilter', newFilters);
};

// Filter functions
const applyInboxFilter = (inbox) => {
  selectedInbox.value = inbox;
  updateFilters();
};

const applyAssigneeFilter = (assignee) => {
  selectedAssignee.value = assignee;
  updateFilters();
};

const applyLabelsFilter = (labels) => {
  selectedLabels.value = labels;
  updateFilters();
};

// Navigation function
const openConversation = (card) => {
  const url = conversationUrl({
    accountId: accountId.value,
    id: card.id,
  });
  router.push(`/app/${url}`);
};

// Modal functions
const openConversationModal = (card) => {
  selectedConversation.value = card;
  showConversationModal.value = true;
};

const closeConversationModal = () => {
  showConversationModal.value = false;
  selectedConversation.value = null;
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

const scrollLeft = () => {
  if (stagesContainer.value) {
    stagesContainer.value.scrollBy({
      left: -320, // Width of one stage
      behavior: 'smooth'
    });
  }
};

const scrollRight = () => {
  if (stagesContainer.value) {
    stagesContainer.value.scrollBy({
      left: 320, // Width of one stage
      behavior: 'smooth'
    });
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

const onDragEnd = (e) => {
  draggingCardId.value = null;
  dragOverStageId.value = null;
  dragOverCardId.value = null;
  e.target.style.opacity = '';
};

const onDrop = (e, stageId) => {
  e.preventDefault();
  const cardId = Number(e.dataTransfer.getData('text/plain'));
  if (!cardId) return;
  const fromStageId = Number(e.dataTransfer.getData('fromStageId'));

  if (fromStageId !== stageId) {
    store.dispatch('kanban/moveCard', { cardId, fromStageId, toStageId: stageId });
  }

  dragOverStageId.value = null;
};

const onDragOver = (e, stageId) => {
  e.preventDefault();
  e.dataTransfer.dropEffect = 'move';
  dragOverStageId.value = stageId;
};

const onDragLeave = (e) => {
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

const filteredCards = (stageId) => {
  const q = (filters.value.q || '').toLowerCase().trim();
  const list = rawCardsForStage(stageId);
  if (!q) return list;
  return list.filter(card =>
    String(card.contact_name || card.title || '').toLowerCase().includes(q) ||
    String(card.subject || '').toLowerCase().includes(q) ||
    String(card.assignee || '').toLowerCase().includes(q) ||
    (card.labels || []).some(l => String(l).toLowerCase().includes(q))
  );
};

const formatLastActivity = (timestamp) => {
  if (!timestamp) return '';
  const date = new Date(timestamp);
  const now = new Date();
  const diffInHours = (now - date) / (1000 * 60 * 60);

  if (diffInHours < 1) {
    return `${Math.floor(diffInHours * 60)}m ago`;
  } else if (diffInHours < 24) {
    return `${Math.floor(diffInHours)}h ago`;
  } else {
    return `${Math.floor(diffInHours / 24)}d ago`;
  }
};
</script>

<template>
  <FeatureToggle :feature-key="FEATURE_FLAGS.KANBAN">
    <div class="flex flex-col h-full w-full overflow-hidden">
      <!-- Header / Filter bar -->
      <div class="flex items-center justify-between w-full gap-2 border-b px-3 h-12 border-n-weak flex-shrink-0">
        <div class="flex items-center gap-4 min-w-0 flex-1">
          <h1 class="min-w-0 text-base font-medium truncate text-n-slate-12">
            {{ $t('KANBAN.BOARD.TITLE') }}
          </h1>
          <div class="flex items-center gap-2 overflow-x-auto">
            <!-- Active filter chips -->
            <NextButton
              v-if="hasActiveFilters"
              xs
              variant="faded"
              color="slate"
              :label="$t('KANBAN.BOARD.SEARCH') + ': ' + (filters.q || '')"
              icon="i-lucide-x"
              trailing-icon
              @click="clearAllFilters"
            />
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
          <router-link :to="{ name: 'kanban_settings' }">
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

      <!-- Secondary filter row -->
      <div class="border-b p-3 flex gap-3 items-center bg-n-background">
        <Input
          :model-value="filters.q"
          :placeholder="$t('KANBAN.BOARD.SEARCH')"
          class="w-72"
          :custom-input-class="'!pl-9'"
          @update:modelValue="val => store.dispatch('kanban/setFilter', { q: val })"
        >
          <template #prefix>
            <div class="pointer-events-none absolute ltr:left-3 rtl:right-3 top-1/2 -translate-y-1/2 text-n-slate-10">
              <Icon icon="i-lucide-search" class="size-4" />
            </div>
          </template>
        </Input>
        <div class="hidden md:flex gap-2">
          <!-- Inbox Filter -->
          <div class="relative">
            <select
              v-model="selectedInbox"
              class="px-3 py-1 text-xs border border-n-weak rounded-md bg-n-background text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
              @change="applyInboxFilter(selectedInbox)"
            >
              <option :value="null">{{ $t('KANBAN.BOARD.INBOX') }}</option>
              <option v-for="inbox in inboxesList" :key="inbox.id" :value="inbox">
                {{ inbox.name }}
              </option>
            </select>
          </div>

          <!-- Assignee Filter -->
          <div class="relative">
            <select
              v-model="selectedAssignee"
              class="px-3 py-1 text-xs border border-n-weak rounded-md bg-n-background text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
              @change="applyAssigneeFilter(selectedAssignee)"
            >
              <option :value="null">{{ $t('KANBAN.BOARD.ASSIGNEE') }}</option>
              <option v-for="agent in agentsList" :key="agent.id" :value="agent">
                {{ agent.name }}
              </option>
            </select>
          </div>

          <!-- Labels Filter -->
          <div class="relative">
            <select
              v-model="selectedLabels"
              multiple
              class="px-3 py-1 text-xs border border-n-weak rounded-md bg-n-background text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
              @change="applyLabelsFilter(selectedLabels)"
            >
              <option v-for="label in labelsList" :key="label.id" :value="label">
                {{ label.title }}
              </option>
            </select>
          </div>
        </div>
      </div>

      <!-- Columns -->
      <div class="flex-1 overflow-hidden relative">
        <!-- Scroll Left Button -->
        <button
          v-show="canScrollLeft"
          @click="scrollLeft"
          class="absolute left-2 top-1/2 transform -translate-y-1/2 z-10 bg-n-background border border-n-weak rounded-full p-2 shadow-lg hover:bg-n-alpha-2 transition-colors"
        >
          <Icon icon="i-lucide-chevron-left" class="size-5 text-n-slate-12" />
        </button>

        <!-- Scroll Right Button -->
        <button
          v-show="canScrollRight"
          @click="scrollRight"
          class="absolute right-2 top-1/2 transform -translate-y-1/2 z-10 bg-n-background border border-n-weak rounded-full p-2 shadow-lg hover:bg-n-alpha-2 transition-colors"
        >
          <Icon icon="i-lucide-chevron-right" class="size-5 text-n-slate-12" />
        </button>

        <div
          ref="stagesContainer"
          class="flex gap-4 p-4 min-h-full snap-x snap-mandatory overflow-x-auto overflow-y-hidden scroll-smooth"
          @scroll="checkScrollButtons"
        >
          <section
            v-for="stage in stages"
            :key="stage.id"
            class="min-w-[320px] max-w-[380px] flex flex-col border border-n-weak rounded-xl bg-n-alpha-black2 dark:bg-n-alpha-2 snap-start transition-all duration-200"
            :class="{
              'ring-2 ring-n-brand/60 shadow-lg scale-[1.02] bg-n-brand/5': dragOverStageId === stage.id,
              'shadow-sm': dragOverStageId !== stage.id
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
                <span class="inline-block size-2 rounded-sm" :style="{ backgroundColor: stage.color }" />
                <h3 class="font-medium text-sm text-n-slate-12">{{ stage.name }}</h3>
              </div>
              <span class="text-xs text-n-slate-11 rounded-full px-2 py-0.5 bg-n-alpha-black2">{{ stage.count }}</span>
            </header>

            <ul
              role="list"
              class="flex-1 overflow-y-auto p-2 space-y-2 scroll-smooth max-h-[calc(100vh-280px)] scrollbar-thin scrollbar-thumb-n-slate-6 scrollbar-track-n-slate-2"
              @scroll="e => onColumnScroll(e, stage.id)"
            >
              <!-- Cards -->
              <li
                v-for="card in filteredCards(stage.id)"
                :key="card.id"
                class="p-3 rounded-lg border border-n-weak bg-n-background cursor-grab group transition-all duration-200 ease-out hover:shadow-lg hover:-translate-y-1 hover:border-n-brand/30 relative"
                :class="{
                  'opacity-50 scale-95 rotate-2 shadow-xl ring-2 ring-n-brand/50': draggingCardId === card.id,
                  'cursor-grabbing': draggingCardId === card.id
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
                  class="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity bg-n-brand text-white rounded-full p-1 hover:bg-n-brand-dark z-10"
                  @click.stop="
                  openConversation(card)
                "
                  :title="$t('KANBAN.BOARD.OPEN_CONVERSATION')"
                >
                  <Icon icon="i-lucide-external-link" class="size-3" />
                </button>

                <div class="flex items-start gap-3">
                  <div class="relative">
                    <Avatar :name="card.contact_name || card.title" :size="32" rounded-full class="mt-1" />
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
                        <p class="text-sm font-medium truncate text-n-slate-12 leading-5">
                          {{ card.contact_name || card.title }}
                        </p>
                        <!-- Contact info -->
                        <div class="flex items-center gap-2 mt-1">
                          <span v-if="card.contact_phone" class="text-[10px] text-n-slate-10 flex items-center gap-1">
                            <Icon icon="i-lucide-phone" class="size-3" />
                            {{ card.contact_phone }}
                          </span>
                          <span v-if="card.contact_email" class="text-[10px] text-n-slate-10 flex items-center gap-1">
                            <Icon icon="i-lucide-mail" class="size-3" />
                            {{ card.contact_email }}
                          </span>
                        </div>
                      </div>
                      <span
                        v-if="card.unread_count && card.unread_count > 0"
                        class="inline-flex items-center justify-center rounded-full bg-n-ruby-9 text-white text-[10px] px-1.5 py-0.5 font-medium ml-2 flex-shrink-0"
                        :aria-label="$t('CONVERSATION.UNREAD_COUNT', { count: card.unread_count })"
                      >
                        {{ card.unread_count }}
                      </span>
                    </div>

                    <!-- Message preview -->
                    <p class="text-xs text-n-slate-11 truncate mb-2 leading-4 line-clamp-2">
                      {{ card.subject || card.last_message || card.title }}
                    </p>

                    <!-- Labels -->
                    <div v-if="card.labels && card.labels.length > 0" class="flex flex-wrap gap-1 mb-2">
                      <span
                        v-for="label in (card.labels || []).slice(0,3)"
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
                    <div class="flex items-center justify-between text-[10px] text-n-slate-10">
                      <div class="flex items-center gap-2 min-w-0 flex-1">
                        <div v-if="card.assignee" class="flex items-center gap-1">
                          <Icon icon="i-lucide-user" class="size-3" />
                          <span class="truncate">{{ card.assignee.name || card.assignee }}</span>
                        </div>
                        <div v-if="card.assignee && card.inbox" class="w-px h-3 bg-n-slate-4" />
                        <InboxName v-if="card.inbox" :inbox="card.inbox" class="text-[10px]" />
                      </div>
                      <span class="text-[10px] text-n-slate-10 ml-2 flex-shrink-0">
                        {{ formatLastActivity(card.updated_at) }}
                      </span>
                    </div>
                  </div>
                  <Icon
                    icon="i-lucide-grip-vertical"
                    class="opacity-0 group-hover:opacity-100 transition-opacity size-4 flex-none text-n-slate-10 cursor-grab mt-1"
                    :class="{ 'cursor-grabbing': draggingCardId === card.id }"
                    :aria-label="$t('KANBAN.BOARD.DRAG_HANDLE_LABEL')"
                    aria-hidden="true"
                  />
                </div>
              </li>

              <!-- Infinite scroll loading indicator -->
              <template v-if="loadingForStage(stage.id)">
                <li v-for="n in 3" :key="`s-${n}`" class="p-3 rounded-lg border border-n-weak bg-n-background animate-pulse">
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
                v-if="!hasMoreForStage(stage.id) && !loadingForStage(stage.id) && filteredCards(stage.id).length > 0"
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

<style scoped>
/* Smooth scrolling for columns */
.scroll-smooth {
  scroll-behavior: smooth;
}

/* Custom scrollbar styles */
.scrollbar-thin {
  scrollbar-width: thin;
}

.scrollbar-thumb-n-slate-6::-webkit-scrollbar-thumb {
  background-color: rgb(var(--n-slate-6));
  border-radius: 4px;
}

.scrollbar-track-n-slate-2::-webkit-scrollbar-track {
  background-color: rgb(var(--n-slate-2));
}

.scrollbar-thin::-webkit-scrollbar {
  width: 6px;
}

/* Enhanced drag and drop visual feedback */
.cursor-grab {
  cursor: grab;
}

.cursor-grabbing {
  cursor: grabbing;
}

/* Drag ghost styling */
[draggable="true"]:active {
  cursor: grabbing;
}

/* Card hover effects - following InboxView patterns */
.group:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px -2px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
}

/* Smooth transitions for all interactive elements */
* {
  transition-property: transform, box-shadow, border-color, background-color, opacity;
  transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
  transition-duration: 200ms;
}

/* Loading skeleton animation - consistent with dashboard */
@keyframes pulse {
  0%, 100% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
}

.animate-pulse {
  animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
}

/* Line clamp utility for text truncation */
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

/* Status indicator styling */
.status-indicator {
  position: relative;
}

.status-indicator::after {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  border-radius: inherit;
  animation: pulse 2s ease-in-out infinite;
}

/* Filter dropdown styles */
select {
  appearance: none;
  background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 20 20'%3e%3cpath stroke='%236b7280' stroke-linecap='round' stroke-linejoin='round' stroke-width='1.5' d='m6 8 4 4 4-4'/%3e%3c/svg%3e");
  background-position: right 0.5rem center;
  background-repeat: no-repeat;
  background-size: 1.5em 1.5em;
  padding-right: 2.5rem;
}

select[multiple] {
  background-image: none;
  padding-right: 0.75rem;
  min-height: 2rem;
}

/* Open conversation button */
.group:hover .absolute.top-2.right-2 {
  opacity: 1;
}

/* Enhanced card hover effects */
.group:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 25px -8px rgba(0, 0, 0, 0.15);
}

/* Consistent spacing and typography */
.kanban-card {
  font-size: 0.875rem;
  line-height: 1.25rem;
}

.kanban-card-title {
  font-weight: 500;
  color: rgb(var(--n-slate-12));
}

.kanban-card-subtitle {
  font-size: 0.75rem;
  line-height: 1rem;
  color: rgb(var(--n-slate-11));
}

.kanban-card-meta {
  font-size: 0.625rem;
  line-height: 0.75rem;
  color: rgb(var(--n-slate-10));
}

/* Better spacing for card content */
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  word-break: break-word;
}

/* Horizontal scroll styles */
.snap-x {
  scroll-snap-type: x mandatory;
}

.snap-start {
  scroll-snap-align: start;
}

/* Hide scrollbar but keep functionality */
.overflow-x-auto::-webkit-scrollbar {
  height: 8px;
}

.overflow-x-auto::-webkit-scrollbar-track {
  background: rgb(var(--n-slate-2));
  border-radius: 4px;
}

.overflow-x-auto::-webkit-scrollbar-thumb {
  background: rgb(var(--n-slate-6));
  border-radius: 4px;
}

.overflow-x-auto::-webkit-scrollbar-thumb:hover {
  background: rgb(var(--n-slate-8));
}

/* Scroll button styles */
.scroll-button {
  backdrop-filter: blur(8px);
  transition: all 0.2s ease;
}

.scroll-button:hover {
  transform: scale(1.05);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}
</style>
