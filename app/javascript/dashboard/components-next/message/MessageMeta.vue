<script setup>
import { computed } from 'vue';
import { messageTimestamp } from 'shared/helpers/timeHelper';

import MessageStatus from './MessageStatus.vue';
import Icon from 'next/icon/Icon.vue';
import { useInbox } from 'dashboard/composables/useInbox';
import { useMessageContext } from './provider.js';

import { MESSAGE_STATUS, MESSAGE_TYPES } from './constants';

const {
  isAFacebookInbox,
  isALineChannel,
  isAPIInbox,
  isASmsInbox,
  isATelegramChannel,
  isATwilioChannel,
  isAWebWidgetInbox,
  isAWhatsAppChannel,
  isAnEmailChannel,
  isAnInstagramChannel,
} = useInbox();

const {
  status,
  isPrivate,
  createdAt,
  sourceId,
  messageType,
  contentAttributes,
  scheduledAt,
} = useMessageContext();

const readableTime = computed(() => {
  // Use scheduled_at for scheduled messages, otherwise use created_at
  const timestamp = status.value === 'scheduled' && scheduledAt.value
    ? scheduledAt.value
    : createdAt.value;

  // Ensure timestamp is valid before formatting
  if (!timestamp || timestamp === null || timestamp === undefined) {
    return '';
  }

  // Convert timestamp to proper format
  let validTimestamp = timestamp;
  if (typeof timestamp === 'number') {
    // Backend sends Unix timestamps in seconds, messageTimestamp expects seconds
    validTimestamp = timestamp;
  } else if (typeof timestamp === 'string') {
    // If it's a string, try to parse it as a date and convert to Unix seconds
    const parsedDate = new Date(timestamp);
    if (!isNaN(parsedDate.getTime())) {
      validTimestamp = Math.floor(parsedDate.getTime() / 1000); // Convert to seconds
    } else {
      console.warn('Invalid timestamp string for message:', timestamp);
      return '';
    }
  }

  try {
    // Validate the timestamp before formatting (check if it's a reasonable Unix timestamp)
    if (typeof validTimestamp !== 'number' || validTimestamp < 0 || validTimestamp > 4102444800) { // Year 2100
      console.warn('Invalid timestamp for message:', timestamp);
      return '';
    }

    return messageTimestamp(validTimestamp, 'LLL d, h:mm a');
  } catch (error) {
    console.warn('Invalid timestamp for message:', timestamp, error);
    return '';
  }
});

const showStatusIndicator = computed(() => {
  if (isPrivate.value) return false;
  // Don't show status for failed messages, we already show error message
  if (status.value === MESSAGE_STATUS.FAILED) return false;
  // Don't show status for deleted messages
  if (contentAttributes.value?.deleted) return false;

  if (messageType.value === MESSAGE_TYPES.OUTGOING) return true;
  if (messageType.value === MESSAGE_TYPES.TEMPLATE) return true;

  return false;
});

const isSent = computed(() => {
  if (!showStatusIndicator.value) return false;

  // Messages will be marked as sent for the Email channel if they have a source ID.
  if (isAnEmailChannel.value) return !!sourceId.value;

  if (
    isAWhatsAppChannel.value ||
    isATwilioChannel.value ||
    isAFacebookInbox.value ||
    isASmsInbox.value ||
    isATelegramChannel.value ||
    isAnInstagramChannel.value
  ) {
    return sourceId.value && status.value === MESSAGE_STATUS.SENT;
  }

  // All messages will be mark as sent for the Line channel, as there is no source ID.
  if (isALineChannel.value) return true;

  return false;
});

const isDelivered = computed(() => {
  if (!showStatusIndicator.value) return false;

  if (
    isAWhatsAppChannel.value ||
    isATwilioChannel.value ||
    isASmsInbox.value ||
    isAFacebookInbox.value
  ) {
    return sourceId.value && status.value === MESSAGE_STATUS.DELIVERED;
  }
  // All messages marked as delivered for the web widget inbox and API inbox once they are sent.
  if (isAWebWidgetInbox.value || isAPIInbox.value) {
    return status.value === MESSAGE_STATUS.SENT;
  }
  if (isALineChannel.value) {
    return status.value === MESSAGE_STATUS.DELIVERED;
  }

  return false;
});

const isRead = computed(() => {
  if (!showStatusIndicator.value) return false;

  if (
    isAWhatsAppChannel.value ||
    isATwilioChannel.value ||
    isAFacebookInbox.value ||
    isAnInstagramChannel.value
  ) {
    return sourceId.value && status.value === MESSAGE_STATUS.READ;
  }

  if (isAWebWidgetInbox.value || isAPIInbox.value) {
    return status.value === MESSAGE_STATUS.READ;
  }

  return false;
});

const statusToShow = computed(() => {
  if (isRead.value) return MESSAGE_STATUS.READ;
  if (isDelivered.value) return MESSAGE_STATUS.DELIVERED;
  if (isSent.value) return MESSAGE_STATUS.SENT;

  return MESSAGE_STATUS.PROGRESS;
});
</script>

<template>
  <div class="text-xs flex items-center gap-1.5">
    <div class="inline">
      <time class="inline">{{ readableTime }}</time>
    </div>
    <Icon v-if="isPrivate" icon="i-lucide-lock-keyhole" class="size-3" />
    <MessageStatus v-if="showStatusIndicator" :status="statusToShow" />
  </div>
</template>
`
