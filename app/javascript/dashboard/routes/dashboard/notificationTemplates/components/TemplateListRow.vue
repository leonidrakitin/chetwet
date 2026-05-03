<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import { getChainLabel } from '../helpers/chainLabel';
import { useStore } from 'dashboard/composables/store';

const props = defineProps({
  template: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['edit', 'delete', 'clone', 'preview']);

const { t } = useI18n();
const store = useStore();

const menuOpen = ref(false);

const toggleMenu = () => {
  menuOpen.value = !menuOpen.value;
};

const closeMenu = () => {
  menuOpen.value = false;
};

const handlePreview = () => {
  closeMenu();
  emit('preview', props.template);
};

const handleEdit = () => {
  closeMenu();
  emit('edit', props.template);
};

const handleClone = () => {
  closeMenu();
  emit('clone', props.template.id);
};

const handleDelete = () => {
  closeMenu();
  emit('delete', props.template);
};

const eventLabel = template => getChainLabel(template, t);

// Stats derived from store
const statistics = computed(
  () => store.getters['notificationTemplates/getStatistics']
);
const templateStats = computed(() => statistics.value[props.template.id] || {});

const sentCount = computed(() => templateStats.value.sent || 0);
const failedCount = computed(() => templateStats.value.failed || 0);
const totalCount = computed(() => {
  const s = templateStats.value;
  return (s.sent || 0) + (s.failed || 0) + (s.skipped || 0) + (s.replied || 0);
});

const hasError = computed(() => !!props.template.metadata?.last_error);

const borderColorClass = computed(() => {
  const colors = {
    event: 'border-l-indigo-400',
    time: 'border-l-amber-400',
    interval: 'border-l-emerald-400',
  };
  return colors[props.template.type] ?? 'border-l-n-slate-8';
});

const displayMessage = computed(() => {
  if (props.template.messages?.length) {
    const first = props.template.messages[0];
    return typeof first === 'string' ? first : (first.text ?? '');
  }
  return props.template.messageText || '';
});

// For dates
const formattedLastSent = computed(() => {
  if (!props.template.last_sent_at) return '';
  const date = new Date(props.template.last_sent_at);
  return date.toLocaleString();
});

const sentTotalLabel = computed(() =>
  t('NOTIFICATION_TEMPLATES.CARD.SENT_TOTAL', {
    sent: sentCount.value,
    total: totalCount.value
      ? String(totalCount.value)
      : t('NOTIFICATION_TEMPLATES.CARD.UNKNOWN_TOTAL'),
  })
);
</script>

<template>
  <div
    class="relative flex items-center justify-between p-4 rounded-xl border border-n-border-glass-soft border-l-[3px] bg-n-glass-soft hover:border-n-border-glass hover:shadow-md transition-all duration-200 cursor-pointer w-full"
    :class="[borderColorClass, { 'opacity-60': !template.enabled }]"
    @click="handleEdit"
  >
    <div class="flex items-center gap-4 flex-1 min-w-0">
      <div class="flex flex-col gap-1.5 flex-1 min-w-0">
        <div class="flex items-center gap-2">
          <span
            class="size-2.5 rounded-full flex-shrink-0"
            :class="template.enabled ? 'bg-n-teal-9' : 'bg-n-slate-8'"
          />
          <h3
            class="text-base font-semibold text-n-text-display leading-snug truncate"
          >
            {{ template.name }}
          </h3>
          <span
            class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium bg-n-brand/10 text-n-blue-11 whitespace-nowrap"
          >
            {{ eventLabel(template) }}
          </span>
        </div>

        <p class="text-sm text-n-text-body/60 truncate max-w-2xl">
          {{ displayMessage }}
        </p>
      </div>

      <div class="flex items-center gap-6 pr-4">
        <div class="flex flex-col text-right">
          <span class="text-xs text-n-slate-9 mb-0.5">{{
            t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.SENT')
          }}</span>
          <span class="text-sm font-medium text-n-text-display">
            {{ sentTotalLabel }}
          </span>
        </div>

        <div class="flex flex-col text-right">
          <span class="text-xs text-n-slate-9 mb-0.5">{{
            t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.FAILED')
          }}</span>
          <span
            class="text-sm font-medium"
            :class="failedCount > 0 ? 'text-ruby-10' : 'text-n-text-body'"
          >
            {{ failedCount }}
          </span>
        </div>

        <div v-if="template.last_sent_at" class="flex flex-col text-right w-36">
          <span class="text-xs text-n-slate-9 mb-0.5">
            {{ t('NOTIFICATION_TEMPLATES.LAST_SENT') }}
          </span>
          <span class="text-xs text-n-text-body whitespace-nowrap">{{
            formattedLastSent
          }}</span>
        </div>

        <div v-if="hasError" class="relative group">
          <div
            class="flex items-center justify-center size-8 rounded-full bg-n-ruby-3 text-n-ruby-11"
          >
            <span class="i-lucide-alert-triangle size-4" />
          </div>
          <!-- Tooltip for error -->
          <div
            class="absolute bottom-full right-0 mb-2 hidden group-hover:block w-64 p-2 bg-n-slate-12 text-n-slate-1 text-xs rounded-lg shadow-lg z-50 pointer-events-none break-words whitespace-pre-wrap"
          >
            {{ template.metadata?.last_error }}
          </div>
        </div>
      </div>
    </div>

    <!-- Actions Menu -->
    <OnClickOutside @trigger="closeMenu">
      <div class="relative flex-shrink-0 ml-2">
        <Button
          variant="ghost"
          color="slate"
          size="sm"
          icon="i-lucide-ellipsis"
          @click.stop="toggleMenu"
        />
        <div
          v-if="menuOpen"
          class="absolute right-0 top-10 z-50 min-w-36 rounded-lg border border-n-border-glass-soft bg-n-glass-soft shadow-lg py-1"
        >
          <button
            class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-text-display hover:bg-n-alpha-1 transition-colors"
            @click.stop="handlePreview"
          >
            <span class="i-lucide-eye size-4 text-n-text-body/60" />
            {{ t('NOTIFICATION_TEMPLATES.PREVIEW.BUTTON_TEXT') }}
          </button>
          <button
            class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-text-display hover:bg-n-alpha-1 transition-colors"
            @click.stop="handleEdit"
          >
            <span class="i-lucide-pencil size-4 text-n-text-body/60" />
            {{ t('NOTIFICATION_TEMPLATES.EDIT.BUTTON_TEXT') }}
          </button>
          <button
            class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-text-display hover:bg-n-alpha-1 transition-colors"
            @click.stop="handleClone"
          >
            <span class="i-lucide-copy size-4 text-n-text-body/60" />
            {{ t('NOTIFICATION_TEMPLATES.CLONE.BUTTON_TEXT') }}
          </button>
          <button
            class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-ruby-11 hover:bg-n-alpha-1 transition-colors"
            @click.stop="handleDelete"
          >
            <span class="i-lucide-trash-2 size-4" />
            {{ t('NOTIFICATION_TEMPLATES.DELETE.BUTTON_TEXT') }}
          </button>
        </div>
      </div>
    </OnClickOutside>
  </div>
</template>
