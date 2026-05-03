<script setup>
import { ref, computed } from 'vue';
import { emitter } from 'shared/helpers/mitt';
import { useTrack } from 'dashboard/composables';

import { BUS_EVENTS } from 'shared/constants/busEvents';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import { COPILOT_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import MessageFormatter from 'shared/helpers/MessageFormatter.js';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  isLastMessage: {
    type: Boolean,
    default: false,
  },
  message: {
    type: Object,
    required: true,
  },
  conversationInboxType: {
    type: String,
    required: true,
  },
});
const hasEmptyMessageContent = computed(() => !props.message?.content);

const showUseButton = computed(() => {
  return (
    !hasEmptyMessageContent.value &&
    props.message.reply_suggestion &&
    props.isLastMessage
  );
});

const messageContent = computed(() => {
  const formatter = new MessageFormatter(props.message.content);
  return formatter.formattedMessage;
});

const insertIntoRichEditor = computed(() => {
  return [INBOX_TYPES.WEB, INBOX_TYPES.EMAIL].includes(
    props.conversationInboxType
  );
});

const hasReasoning = computed(() => !!props.message?.reasoning);
const isReasoningExpanded = ref(false);

const useCopilotResponse = () => {
  if (insertIntoRichEditor.value) {
    emitter.emit(BUS_EVENTS.INSERT_INTO_RICH_EDITOR, props.message?.content);
  } else {
    emitter.emit(BUS_EVENTS.INSERT_INTO_NORMAL_EDITOR, props.message?.content);
  }
  useTrack(COPILOT_EVENTS.USE_CAPTAIN_RESPONSE);
};
</script>

<template>
  <div class="flex flex-col gap-1 text-n-text-display">
    <div class="font-medium">{{ $t('CAPTAIN.NAME') }}</div>
    <span v-if="hasEmptyMessageContent" class="text-n-ruby-11">
      {{ $t('CAPTAIN.COPILOT.EMPTY_MESSAGE') }}
    </span>
    <div
      v-else
      v-dompurify-html="messageContent"
      class="prose-sm break-words"
    />
    <div v-if="hasReasoning" class="mt-1">
      <button
        class="flex items-center gap-1 text-xs text-n-slate-9 hover:text-n-text-body transition-colors"
        @click="isReasoningExpanded = !isReasoningExpanded"
      >
        <Icon
          :icon="
            isReasoningExpanded
              ? 'i-lucide-chevron-down'
              : 'i-lucide-chevron-right'
          "
          class="w-3 h-3"
        />
        {{ $t('CAPTAIN.COPILOT.REASONING') }}
      </button>
      <div
        v-show="isReasoningExpanded"
        class="mt-1 p-2 text-xs text-n-text-body/60 whitespace-pre-wrap leading-relaxed rounded bg-n-background/50 border border-n-border-glass-soft"
      >
        {{ message.reasoning }}
      </div>
    </div>
    <div class="flex flex-row mt-1">
      <Button
        v-if="showUseButton"
        :label="$t('CAPTAIN.COPILOT.USE')"
        faded
        sm
        slate
        @click="useCopilotResponse"
      />
    </div>
  </div>
</template>
