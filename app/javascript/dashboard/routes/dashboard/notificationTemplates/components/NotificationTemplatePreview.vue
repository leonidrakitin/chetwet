<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  messages: {
    type: Array,
    default: () => [],
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

const substituteVars = text =>
  text.replace(
    /\{(\w+)\}/g,
    (match, key) => EXAMPLE_VALUES[key.trim()] ?? match
  );

const previewMessages = computed(() =>
  props.messages.map(substituteVars).filter(Boolean)
);

const getAttachmentIcon = type => {
  const icons = {
    file: 'i-lucide-file',
    photo: 'i-lucide-image',
    video: 'i-lucide-video',
    link: 'i-lucide-link',
  };
  return icons[type] ?? 'i-lucide-paperclip';
};

const hasContent = computed(
  () =>
    previewMessages.value.length ||
    props.attachments.length ||
    props.buttons.length
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
        <!-- One bubble per message -->
        <div
          v-for="(text, idx) in previewMessages"
          :key="idx"
          class="rounded-xl rounded-tr-sm bg-n-brand px-3 py-2 text-sm text-white max-w-full whitespace-pre-wrap break-words"
        >
          {{ text }}
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
