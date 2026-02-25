<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  messageText: {
    type: String,
    default: '',
  },
  attachments: {
    type: Array,
    default: () => [],
  },
  buttons: {
    type: Array,
    default: () => [],
  },
});

const { t } = useI18n();

const EXAMPLE_VALUES = {
  client_name: 'Иван Иванов',
  service_name: 'Стрижка',
  branch_name: 'Центральный офис',
  master_name: 'Мария',
  price: '1 500 ₽',
  date: '15 марта',
  time: '14:30',
};

const VARIABLE_COLORS = {
  client_name: { bg: '#dbeafe', text: '#1d4ed8' },
  service_name: { bg: '#ccfbf1', text: '#0f766e' },
  branch_name: { bg: '#fef3c7', text: '#b45309' },
  master_name: { bg: '#ede9fe', text: '#7c3aed' },
  price: { bg: '#fee2e2', text: '#b91c1c' },
  date: { bg: '#ffedd5', text: '#c2410c' },
  time: { bg: '#e2e8f0', text: '#334155' },
};

const getAttachmentIcon = type => {
  const icons = {
    file: 'i-lucide-file',
    photo: 'i-lucide-image',
    video: 'i-lucide-video',
    link: 'i-lucide-link',
  };
  return icons[type] ?? 'i-lucide-paperclip';
};

// Split message into segments: { type: 'text'|'variable', value, key? }
const messageParts = computed(() => {
  if (!props.messageText) return [];
  const parts = [];
  const regex = /\{(\w+)\}/g;
  let lastIndex = 0;

  Array.from(props.messageText.matchAll(regex)).forEach(match => {
    if (match.index > lastIndex) {
      parts.push({
        type: 'text',
        value: props.messageText.slice(lastIndex, match.index),
      });
    }
    const key = match[1];
    parts.push({
      type: 'variable',
      key,
      value: EXAMPLE_VALUES[key] ?? match[0],
    });
    lastIndex = match.index + match[0].length;
  });

  if (lastIndex < props.messageText.length) {
    parts.push({ type: 'text', value: props.messageText.slice(lastIndex) });
  }
  return parts;
});

const hasContent = computed(
  () => props.messageText || props.attachments.length || props.buttons.length
);
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="text-xs font-medium text-n-slate-11 uppercase tracking-wide">
      {{ t('NOTIFICATION_TEMPLATES.PREVIEW.TITLE') }}
    </p>

    <div
      class="flex flex-col gap-3 rounded-xl bg-n-alpha-1 border border-n-weak p-4 min-h-48"
    >
      <div v-if="hasContent" class="flex flex-col items-end gap-2">
        <!-- Message bubble -->
        <div
          v-if="messageText"
          class="rounded-xl rounded-tr-sm bg-n-brand px-3 py-2 text-sm text-white max-w-full whitespace-pre-wrap break-words"
        >
          <template v-for="(part, idx) in messageParts" :key="idx">
            <span
              v-if="part.type === 'variable'"
              class="inline rounded px-1 font-medium"
              :style="{
                backgroundColor: VARIABLE_COLORS[part.key]?.bg ?? '#e2e8f0',
                color: VARIABLE_COLORS[part.key]?.text ?? '#334155',
              }"
              >{{ part.value }}</span
            >
            <span v-else>{{ part.value }}</span>
          </template>
        </div>

        <!-- Attachments -->
        <div v-if="attachments.length" class="flex flex-wrap gap-1 justify-end">
          <div
            v-for="att in attachments"
            :key="att.id"
            class="flex items-center gap-1 rounded-lg border border-n-weak bg-n-solid-1 px-2 py-1 text-xs text-n-slate-11"
          >
            <span class="size-3" :class="getAttachmentIcon(att.type)" />
            <span class="max-w-24 truncate">{{ att.name }}</span>
          </div>
        </div>

        <!-- Buttons -->
        <div v-if="buttons.length" class="flex flex-col gap-1 w-full">
          <div
            v-for="btn in buttons"
            :key="btn.id"
            class="border border-n-blue-9 text-n-blue-11 rounded-lg px-3 py-1.5 text-sm text-center"
          >
            {{ btn.label }}
          </div>
        </div>
      </div>

      <div
        v-else
        class="flex flex-1 items-center justify-center h-full py-8 text-center"
      >
        <p class="text-xs text-n-slate-9 italic">
          {{ t('NOTIFICATION_TEMPLATES.PREVIEW.PLACEHOLDER') }}
        </p>
      </div>
    </div>

    <p class="text-xs text-n-slate-9">
      {{ t('NOTIFICATION_TEMPLATES.PREVIEW.EXAMPLE_LABEL') }}
    </p>
  </div>
</template>
