<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  messages: {
    type: Array,
    default: () => [],
  },
  highlightVariableKey: {
    type: String,
    default: null,
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

const substituteVars = text =>
  text
    .replace(/@(\w+)/g, (match, key) => EXAMPLE_VALUES[key.trim()] ?? match)
    .replace(/\{(\w+)\}/g, (match, key) => EXAMPLE_VALUES[key.trim()] ?? match);

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
        text: isString ? substituteVars(m) : substituteVars(m.text ?? ''),
        attachments: isString ? [] : (m.attachments ?? []),
        buttons: isString ? [] : (m.buttons ?? []),
      };
    })
    .filter(b => b.text || b.attachments.length || b.buttons.length)
);

const hasContent = computed(() => previewBlocks.value.length > 0);

const getTextSegments = (displayText, key) => {
  if (!key || !displayText) return [{ type: 'text', value: displayText }];
  const needle = EXAMPLE_VALUES[key];
  if (!needle) return [{ type: 'text', value: displayText }];
  const parts = displayText.split(needle);
  const segments = [];
  parts.forEach((p, i) => {
    if (p) segments.push({ type: 'text', value: p });
    if (i < parts.length - 1)
      segments.push({ type: 'highlight', value: needle });
  });
  return segments.length ? segments : [{ type: 'text', value: displayText }];
};
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
            v-if="block.text"
            class="rounded-xl rounded-tr-sm bg-n-brand px-3 py-2 text-sm text-white max-w-full whitespace-pre-wrap break-words"
          >
            <template
              v-for="(seg, segIdx) in getTextSegments(
                block.text,
                highlightVariableKey
              )"
              :key="segIdx"
            >
              <span
                v-if="seg.type === 'highlight'"
                class="rounded bg-n-amber-4 text-n-slate-12 px-0.5"
              >
                {{ seg.value }}
              </span>
              <span v-else>{{ seg.value }}</span>
            </template>
          </div>

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
