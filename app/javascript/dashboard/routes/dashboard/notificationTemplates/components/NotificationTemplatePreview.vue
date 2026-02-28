<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  messages: {
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

const applyInline = str =>
  str
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/~~(.+?)~~/g, '<s>$1</s>')
    .replace(
      /`([^`]+)`/g,
      '<code class="bg-white/20 rounded px-0.5 text-xs font-mono">$1</code>'
    )
    .replace(/_(.+?)_/g, '<em>$1</em>')
    .replace(
      /\[([^\]]+)\]\(([^)]+)\)/g,
      '<a href="$2" target="_blank" rel="noopener noreferrer" class="underline">$1</a>'
    );

const renderMarkdown = text => {
  if (!text) return '';
  const substituted = text
    .replace(/@(\w+)/g, (_, k) => EXAMPLE_VALUES[k] ?? `@${k}`)
    .replace(/\{(\w+)\}/g, (_, k) => EXAMPLE_VALUES[k] ?? `{${k}}`);

  const lines = substituted.split('\n');
  const parts = [];
  const ulItems = [];
  const olItems = [];

  const flushUl = () => {
    if (ulItems.length) {
      parts.push(
        `<ul class="list-disc list-inside space-y-0.5">${ulItems.join('')}</ul>`
      );
      ulItems.length = 0;
    }
  };
  const flushOl = () => {
    if (olItems.length) {
      parts.push(
        `<ol class="list-decimal list-inside space-y-0.5">${olItems.join('')}</ol>`
      );
      olItems.length = 0;
    }
  };

  lines.forEach(line => {
    const ulMatch = /^[-*] (.*)$/.exec(line);
    const olMatch = /^\d+\. (.*)$/.exec(line);
    if (ulMatch) {
      flushOl();
      ulItems.push(`<li>${applyInline(ulMatch[1])}</li>`);
    } else if (olMatch) {
      flushUl();
      olItems.push(`<li>${applyInline(olMatch[1])}</li>`);
    } else {
      flushUl();
      flushOl();
      parts.push(applyInline(line));
    }
  });
  flushUl();
  flushOl();

  return parts.join('<br>');
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

const previewBlocks = computed(() =>
  props.messages
    .map(m => {
      const isString = typeof m === 'string';
      return {
        html: renderMarkdown(isString ? m : (m.text ?? '')),
        attachments: isString ? [] : (m.attachments ?? []),
        buttons: isString ? [] : (m.buttons ?? []),
      };
    })
    .filter(b => b.html || b.attachments.length || b.buttons.length)
);

const hasContent = computed(() => previewBlocks.value.length > 0);
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="text-xs font-medium text-n-slate-11 uppercase tracking-wide">
      {{ t('NOTIFICATION_TEMPLATES.PREVIEW.TITLE') }}
    </p>

    <div
      class="flex flex-col gap-3 rounded-xl bg-n-alpha-1 border border-n-weak p-4 min-h-48"
    >
      <div v-if="hasContent" class="flex flex-col items-end gap-3">
        <div
          v-for="(block, idx) in previewBlocks"
          :key="idx"
          class="flex flex-col items-end gap-1 w-full"
        >
          <!-- Text bubble -->
          <div
            v-if="block.html"
            class="rounded-xl rounded-tr-sm bg-n-brand px-3 py-2 text-sm text-white max-w-full break-words"
            v-html="block.html"
          />

          <!-- Attachments -->
          <div
            v-if="block.attachments.length"
            class="flex flex-wrap gap-1 justify-end"
          >
            <div
              v-for="att in block.attachments"
              :key="att.id"
              class="flex items-center gap-1 rounded-lg border border-n-weak bg-n-solid-1 px-2 py-1 text-xs text-n-slate-11"
            >
              <span class="size-3" :class="getAttachmentIcon(att.type)" />
              <span class="max-w-24 truncate">{{ att.name }}</span>
            </div>
          </div>

          <!-- Buttons -->
          <div v-if="block.buttons.length" class="flex flex-col gap-1 w-full">
            <div
              v-for="btn in block.buttons"
              :key="btn.id"
              class="border border-n-blue-9 text-n-blue-11 rounded-lg px-3 py-1.5 text-sm text-center"
            >
              {{ btn.label }}
            </div>
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
