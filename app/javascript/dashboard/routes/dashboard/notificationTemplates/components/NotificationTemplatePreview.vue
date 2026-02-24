<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  messageText: {
    type: String,
    default: '',
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

const processedMessage = computed(() => {
  if (!props.messageText) return '';
  return props.messageText.replace(/\{(\w+)\}/g, (match, variable) => {
    return EXAMPLE_VALUES[variable] ?? match;
  });
});
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="text-xs font-medium text-n-slate-11 uppercase tracking-wide">
      {{ t('NOTIFICATION_TEMPLATES.PREVIEW.TITLE') }}
    </p>

    <div
      class="flex flex-col gap-3 rounded-xl bg-n-alpha-1 border border-n-weak p-4 min-h-48"
    >
      <div v-if="processedMessage" class="flex justify-end">
        <div
          class="rounded-xl rounded-tr-sm bg-n-brand px-3 py-2 text-sm text-white max-w-full whitespace-pre-wrap break-words"
        >
          {{ processedMessage }}
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
