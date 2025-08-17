<script setup>
import { ref } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Avatar from 'next/avatar/Avatar.vue';

defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  conversation: {
    type: Object,
    default: null,
  },
});

defineEmits(['close']);

const messageText = ref('');

const formatLastActivity = timestamp => {
  if (!timestamp) return '';
  const date = new Date(timestamp);
  return date.toLocaleDateString('pt-BR', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const sendMessage = () => {
  if (!messageText.value.trim()) return;

  // TODO: Implement message sending
  messageText.value = '';
};
</script>

<template>
  <div
    v-if="show"
    class="fixed inset-0 z-50 flex items-center justify-center bg-modal-backdrop-light dark:bg-modal-backdrop-dark"
    @click.self="$emit('close')"
  >
    <div
      class="w-full max-w-6xl h-full max-h-[90vh] bg-n-background rounded-lg shadow-xl overflow-hidden"
    >
      <!-- Header -->
      <div class="flex items-center justify-between p-4 border-b border-n-weak">
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ $t('KANBAN.MODAL.TITLE', { contactName: conversation?.contact_name }) }}
        </h2>
        <button
          class="p-2 rounded-lg hover:bg-n-alpha-2 transition-colors"
          @click="$emit('close')"
        >
          <Icon icon="i-lucide-x" class="size-5 text-n-slate-11" />
        </button>
      </div>

      <!-- Conversation Interface -->
      <div
        class="conversation-details-wrap flex flex-col min-w-0 w-full bg-n-background relative h-full"
      >
        <!-- Conversation Header -->
        <div
          class="flex flex-col gap-3 items-center justify-between flex-1 w-full min-w-0 xl:flex-row px-3 py-2 border-b bg-n-background border-n-weak h-24 xl:h-12"
        >
          <div
            class="flex items-center justify-start w-full xl:w-auto max-w-full min-w-0 xl:flex-1"
          >
            <Avatar
              :name="conversation?.contact_name"
              :size="32"
              rounded-full
            />
            <div
              class="flex flex-col items-start min-w-0 ml-2 overflow-hidden rtl:ml-0 rtl:mr-2"
            >
              <div class="flex flex-row items-center max-w-full gap-1 p-0 m-0">
                <span
                  class="text-sm font-medium truncate leading-tight text-n-slate-12"
                >
                  {{ conversation?.contact_name }}
                </span>
                <Icon
                  v-if="conversation?.status === 'pending'"
                  icon="i-lucide-alert-triangle"
                  class="text-n-amber-10 my-0 mx-0 min-w-[14px] flex-shrink-0"
                  :size="14"
                />
              </div>
              <div
                class="flex items-center gap-2 overflow-hidden text-xs conversation--header--actions text-ellipsis whitespace-nowrap"
              >
                <span
                  v-if="conversation?.contact_phone"
                  class="text-n-slate-10"
                >
                  {{ conversation.contact_phone }}
                </span>
                <span
                  v-if="conversation?.contact_email"
                  class="text-n-slate-10"
                >
                  {{ conversation.contact_email }}
                </span>
              </div>
            </div>
          </div>

          <!-- Action Buttons -->
          <div
            class="flex flex-row items-center justify-start xl:justify-end flex-shrink-0 gap-2 w-full xl:w-auto header-actions-wrap"
          >
            <div class="relative flex items-center gap-2 actions--container">
              <div
                class="relative flex items-center justify-end resolve-actions"
              >
                <div
                  class="rounded-lg shadow outline-1 outline flex-shrink-0 outline-n-container"
                >
                  <button
                    class="ltr:rounded-r-none rtl:rounded-l-none !outline-0 inline-flex items-center min-w-0 gap-2 transition-all duration-200 ease-in-out border-0 rounded-lg outline-1 outline disabled:opacity-50 bg-n-solid-3 dark:hover:enabled:bg-n-solid-2 dark:focus-visible:bg-n-solid-2 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 text-n-slate-12 outline-n-container h-8 px-3 text-sm justify-center"
                  >
                    <span class="min-w-0 truncate">{{
                      $t('KANBAN.MODAL.RESOLVE')
                    }}</span>
                  </button>
                  <button
                    class="ltr:rounded-l-none rtl:rounded-r-none !outline-0 inline-flex items-center min-w-0 gap-2 transition-all duration-200 ease-in-out border-0 rounded-lg outline-1 outline disabled:opacity-50 bg-n-solid-3 dark:hover:enabled:bg-n-solid-2 dark:focus-visible:bg-n-solid-2 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 text-n-slate-12 outline-n-container h-8 w-8 p-0 text-sm justify-center"
                  >
                    <Icon icon="i-lucide-chevron-down" class="flex-shrink-0" />
                  </button>
                </div>
              </div>
              <div class="relative flex items-center group">
                <button
                  class="rounded-md group-hover:bg-n-alpha-2 inline-flex items-center min-w-0 gap-2 transition-all duration-200 ease-in-out border-0 rounded-lg outline-1 outline disabled:opacity-50 text-n-slate-12 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 outline-transparent h-8 w-8 p-0 text-sm justify-center"
                >
                  <Icon icon="i-lucide-more-vertical" class="flex-shrink-0" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Tabs -->
        <div
          class="flex border-b border-b-n-weak -mt-px border-t border-t-n-background"
        >
          <button
            class="items-center rounded-none cursor-pointer flex h-auto justify-center min-w-8"
          >
            <Icon icon="i-lucide-chevron-left" :size="16" />
          </button>
          <ul
            class="border-r-0 border-l-0 border-t-0 flex min-w-[6.25rem] py-0 px-4 list-none mb-0 overflow-hidden py-0 px-1 max-w-[calc(100%-64px)]"
          >
            <li
              class="flex-shrink-0 my-0 mx-2 ltr:first:ml-0 rtl:first:mr-0 ltr:last:mr-0 rtl:last:ml-0 hover:text-n-slate-12"
            >
              <a
                class="flex items-center flex-row border-b select-none cursor-pointer text-sm relative top-[1px] transition-[border-color] duration-[150ms] ease-[cubic-bezier(0.37,0,0.63,1)] border-b border-n-brand text-n-blue-text py-2 text-sm"
              >
                {{ $t('KANBAN.MODAL.MESSAGES') }}
              </a>
            </li>
            <li
              class="flex-shrink-0 my-0 mx-2 ltr:first:ml-0 rtl:first:mr-0 ltr:last:mr-0 rtl:last:ml-0 hover:text-n-slate-12"
            >
              <a
                class="flex items-center flex-row border-b select-none cursor-pointer text-sm relative top-[1px] transition-[border-color] duration-[150ms] ease-[cubic-bezier(0.37,0,0.63,1)] border-transparent text-n-slate-11 py-2 text-sm"
              >
                {{ conversation?.inbox?.name }}
              </a>
            </li>
          </ul>
          <button
            class="items-center rounded-none cursor-pointer flex h-auto justify-center min-w-8"
          >
            <Icon icon="i-lucide-chevron-right" :size="16" />
          </button>
        </div>

        <!-- Messages Area -->
        <div class="flex h-full min-h-0 m-0 flex-1">
          <div
            class="flex flex-col justify-between flex-grow h-full min-w-0 m-0"
          >
            <!-- Messages List -->
            <ul
              class="px-4 bg-n-background conversation-panel flex-shrink flex-grow basis-px flex flex-col overflow-y-auto relative h-full m-0 pb-4"
            >
              <li
                class="min-h-[4rem] flex flex-shrink-0 flex-grow-0 items-center flex-auto justify-center max-w-full mt-0 mr-0 mb-1 ml-0 relative first:mt-auto last:mb-0"
              >
                <!-- Empty state or loading -->
              </li>

              <!-- Sample Message -->
              <div
                class="flex w-full message-bubble-container mb-2 justify-start"
              >
                <div
                  class="grid grid-cols-1fr gap-x-2"
                  :style="{ 'grid-template-areas': `'bubble' 'meta'` }"
                >
                  <div class="[grid-area:bubble] flex ltr:mr-8 rtl:ml-8">
                    <div
                      class="text-sm bg-n-slate-4 text-n-slate-12 left-bubble rounded-xl ltr:rounded-bl-sm rtl:rounded-br-sm max-w-lg px-4 py-3"
                    >
                      <div class="gap-3 flex flex-col">
                        <span class="prose prose-bubble">
                          <p>
                            {{
                              conversation?.last_message ||
                              'Carregando mensagens...'
                            }}
                          </p>
                        </span>
                      </div>
                      <div
                        class="text-xs flex items-center gap-1.5 justify-start text-n-slate-11 mt-2"
                      >
                        <div class="inline">
                          <time class="inline">{{
                            formatLastActivity(conversation?.updated_at)
                          }}</time>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </ul>

            <!-- Reply Box -->
            <div class="flex relative flex-col bg-n-background">
              <div class="reply-box">
                <div
                  class="flex justify-between h-[3.25rem] gap-2 ltr:pl-3 rtl:pr-3"
                >
                  <button
                    class="flex items-center w-auto h-8 p-1 transition-all border rounded-full bg-n-alpha-2 group relative duration-300 ease-in-out z-0 mt-3"
                  >
                    <div class="flex items-center gap-1 px-2 z-20">
                      {{ $t('KANBAN.MODAL.REPLY') }}
                    </div>
                    <div class="flex items-center gap-1 px-2 z-20">
                      {{ $t('KANBAN.MODAL.PRIVATE_NOTE') }}
                    </div>
                    <div
                      class="absolute shadow-sm rounded-full h-6 w-[87px] transition-all duration-300 ease-in-out translate-x-0 bg-n-solid-1"
                    />
                  </button>
                  <div class="flex items-center mx-4 my-0" />
                  <button
                    class="ltr:rounded-bl-md rtl:rounded-br-md ltr:rounded-br-none rtl:rounded-bl-none ltr:rounded-tl-none rtl:rounded-tr-none text-n-slate-11 ltr:rounded-tr-[11px] rtl:rounded-tl-[11px] inline-flex items-center min-w-0 gap-2 transition-all duration-200 ease-in-out border-0 rounded-lg outline-1 outline disabled:opacity-50 text-n-blue-text hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 outline-transparent h-10 w-10 p-0 text-sm font-medium justify-center"
                  >
                    <Icon icon="i-lucide-maximize-2" class="flex-shrink-0" />
                  </button>
                </div>

                <!-- Message Input -->
                <div class="relative w-full input min-h-[4rem]">
                  <div class="border border-n-weak rounded-lg p-3">
                    <textarea
                      v-model="messageText"
                      placeholder="Digite sua mensagem..."
                      class="w-full min-h-[60px] resize-none border-0 outline-none bg-transparent text-n-slate-12 placeholder-n-slate-10"
                      @keydown.ctrl.enter="sendMessage"
                      @keydown.meta.enter="sendMessage"
                    />
                  </div>
                </div>

                <!-- Action Buttons -->
                <div class="flex justify-between p-3">
                  <div class="left-wrap flex gap-2">
                    <button
                      class="inline-flex items-center min-w-0 gap-2 transition-all duration-200 ease-in-out border-0 rounded-lg outline-1 outline disabled:opacity-50 bg-n-slate-9/10 text-n-slate-12 hover:enabled:bg-n-slate-9/20 focus-visible:bg-n-slate-9/20 outline-transparent h-8 w-8 p-0 text-sm justify-center"
                    >
                      <Icon icon="i-ph-smiley-sticker" class="flex-shrink-0" />
                    </button>
                    <button
                      class="inline-flex items-center min-w-0 gap-2 transition-all duration-200 ease-in-out border-0 rounded-lg outline-1 outline disabled:opacity-50 bg-n-slate-9/10 text-n-slate-12 hover:enabled:bg-n-slate-9/20 focus-visible:bg-n-slate-9/20 outline-transparent h-8 w-8 p-0 text-sm justify-center"
                    >
                      <Icon icon="i-ph-paperclip" class="flex-shrink-0" />
                    </button>
                    <button
                      class="inline-flex items-center min-w-0 gap-2 transition-all duration-200 ease-in-out border-0 rounded-lg outline-1 outline disabled:opacity-50 bg-n-slate-9/10 text-n-slate-12 hover:enabled:bg-n-slate-9/20 focus-visible:bg-n-slate-9/20 outline-transparent h-8 w-8 p-0 text-sm justify-center"
                    >
                      <Icon icon="i-ph-microphone" class="flex-shrink-0" />
                    </button>
                  </div>
                  <div class="right-wrap">
                    <button
                      type="submit"
                      :disabled="!messageText.trim()"
                      class="flex-shrink-0 inline-flex items-center min-w-0 gap-2 transition-all duration-200 ease-in-out border-0 rounded-lg outline-1 outline disabled:opacity-50 bg-n-brand text-white hover:enabled:brightness-110 focus-visible:brightness-110 outline-transparent h-8 px-3 text-sm justify-center"
                      @click="sendMessage"
                    >
                      <span class="min-w-0 truncate">{{
                        $t('KANBAN.MODAL.SEND')
                      }}</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
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
