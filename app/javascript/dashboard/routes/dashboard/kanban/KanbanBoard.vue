<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'vuex';
import FeatureToggle from 'dashboard/components/widgets/FeatureToggle.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';
import InboxName from 'dashboard/components/widgets/InboxName.vue';

const store = useStore();
const stages = computed(() => store.getters['kanban/orderedStages']);
const rawCardsForStage = stageId => store.getters['kanban/cardsForStage'](stageId);
const loadingForStage = stageId => store.getters['kanban/loadingForStage'](stageId);
const hasMoreForStage = stageId => store.getters['kanban/hasMoreForStage'](stageId);
const filters = computed(() => store.getters['kanban/filters']);

const draggingCardId = ref(null);
const dragOverStageId = ref(null);
const dragOverCardId = ref(null);
const hasActiveFilters = computed(() => Boolean((filters.value.q || '').trim()));

const clearAllFilters = () => {
  store.dispatch('kanban/setFilter', { q: '' });
};

onMounted(() => {
  store.dispatch('kanban/fetchInitial');
});

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
          <NextButton xs variant="ghost" color="slate" :label="$t('KANBAN.BOARD.INBOX')" />
          <NextButton xs variant="ghost" color="slate" :label="$t('KANBAN.BOARD.ASSIGNEE')" />
          <NextButton xs variant="ghost" color="slate" :label="$t('KANBAN.BOARD.LABELS')" />
          <NextButton xs variant="ghost" color="slate" :label="$t('KANBAN.BOARD.DATE_RANGE')" />
        </div>
      </div>

      <!-- Columns -->
      <div class="flex-1 overflow-x-auto overflow-y-hidden">
        <div class="flex gap-4 p-4 min-h-full snap-x snap-mandatory">
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
              class="flex-1 overflow-y-auto p-2 space-y-2 scroll-smooth"
              @scroll="e => onColumnScroll(e, stage.id)"
            >
              <!-- Cards -->
              <li
                v-for="card in filteredCards(stage.id)"
                :key="card.id"
                class="p-3 rounded-lg border border-n-weak bg-n-background cursor-grab group transition-all duration-200 ease-out hover:shadow-lg hover:-translate-y-1 hover:border-n-brand/30"
                :class="{
                  'opacity-50 scale-95 rotate-2 shadow-xl ring-2 ring-n-brand/50': draggingCardId === card.id,
                  'cursor-grabbing': draggingCardId === card.id
                }"
                draggable="true"
                role="listitem"
                :aria-grabbed="draggingCardId === card.id ? 'true' : 'false'"
                @dragstart="e => onDragStart(e, card, stage.id)"
                @dragend="onDragEnd"
              >
                <div class="flex items-start gap-3">
                  <div class="relative">
                    <Avatar :name="card.contact_name || card.title" :size="28" rounded-full class="mt-1" />
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
                  </div>
                  <div class="min-w-0 flex-1">
                    <div class="flex items-start justify-between mb-1">
                      <p class="text-sm font-medium truncate text-n-slate-12 leading-5">
                        {{ card.contact_name || card.title }}
                      </p>
                      <span
                        v-if="card.unread_count && card.unread_count > 0"
                        class="inline-flex items-center justify-center rounded-full bg-n-ruby-9 text-white text-[10px] px-1.5 py-0.5 font-medium ml-2 flex-shrink-0"
                        :aria-label="$t('CONVERSATION.UNREAD_COUNT', { count: card.unread_count })"
                      >
                        {{ card.unread_count }}
                      </span>
                    </div>
                    <p class="text-xs text-n-slate-11 truncate mb-2 leading-4 line-clamp-2">
                      {{ card.subject || card.last_message || card.title }}
                    </p>
                    <div class="flex items-center justify-between h-6 gap-2">
                      <div class="flex items-center flex-1 min-w-0 gap-1">
                        <div class="flex gap-1">
                          <span
                            v-for="l in (card.labels || []).slice(0,2)"
                            :key="l"
                            class="px-1.5 py-0.5 rounded bg-n-slate-3 text-[10px] text-n-slate-11"
                          >
                            {{ l }}
                          </span>
                          <span
                            v-if="(card.labels || []).length > 2"
                            class="px-1.5 py-0.5 rounded bg-n-slate-3 text-n-slate-11 text-[10px]"
                          >
                            {{ `+${(card.labels || []).length - 2}` }}
                          </span>
                        </div>
                        <div v-if="card.assignee" class="w-px h-3 rounded-sm bg-n-slate-4" />
                        <div v-if="card.assignee" class="flex items-center gap-1">
                          <Icon icon="i-lucide-user" class="size-3 text-n-slate-10" />
                          <span class="text-[10px] text-n-slate-11 truncate">{{ card.assignee }}</span>
                        </div>
                        <div v-if="card.inbox" class="w-px h-3 rounded-sm bg-n-slate-4" />
                        <InboxName v-if="card.inbox" :inbox="card.inbox" />
                        <span class="text-xs text-n-slate-10 ml-auto">
                          {{ formatLastActivity(card.updated_at) }}
                        </span>
                      </div>
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
  </FeatureToggle>
</template>

<style scoped>
/* Smooth scrolling for columns */
.scroll-smooth {
  scroll-behavior: smooth;
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
</style>
