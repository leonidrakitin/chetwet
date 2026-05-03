<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  summary: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

function formatNumber(num) {
  if (num >= 1000000) {
    return `${(num / 1000000).toFixed(1)}M`;
  }
  if (num >= 1000) {
    return `${(num / 1000).toFixed(1)}K`;
  }
  return num.toString();
}

const heroCards = computed(() => [
  {
    key: 'sent',
    label: t('CAMPAIGNS.STATISTICS.SUMMARY.SENT'),
    value: formatNumber(props.summary.sent || 0),
    icon: 'i-lucide-send',
    accent: 'text-blue-500',
    ring: 'bg-blue-500/10',
  },
  {
    key: 'success_rate',
    label: t('CAMPAIGNS.STATISTICS.SUMMARY.SUCCESS_RATE'),
    value: `${props.summary.success_rate || 0}%`,
    icon: 'i-lucide-check-circle',
    accent: 'text-emerald-500',
    ring: 'bg-emerald-500/10',
  },
  {
    key: 'reply_rate',
    label: t('CAMPAIGNS.STATISTICS.SUMMARY.REPLY_RATE'),
    value: `${props.summary.reply_rate || 0}%`,
    icon: 'i-lucide-message-circle',
    accent: 'text-cyan-500',
    ring: 'bg-cyan-500/10',
  },
  {
    key: 'replied',
    label: t('CAMPAIGNS.STATISTICS.SUMMARY.REPLIED'),
    value: formatNumber(props.summary.replied || 0),
    icon: 'i-lucide-reply',
    accent: 'text-teal-500',
    ring: 'bg-teal-500/10',
  },
]);

const secondaryCards = computed(() => [
  {
    key: 'total_campaigns',
    label: t('CAMPAIGNS.STATISTICS.SUMMARY.TOTAL_CAMPAIGNS'),
    value: props.summary.total_campaigns || 0,
    icon: 'i-lucide-layout-list',
    accent: 'text-violet-500',
  },
  {
    key: 'active_campaigns',
    label: t('CAMPAIGNS.STATISTICS.SUMMARY.ACTIVE_CAMPAIGNS'),
    value: props.summary.active_campaigns || 0,
    icon: 'i-lucide-zap',
    accent: 'text-green-500',
  },
  {
    key: 'scheduled_count',
    label: t('CAMPAIGNS.STATISTICS.SUMMARY.SCHEDULED'),
    value: props.summary.scheduled_count || 0,
    icon: 'i-lucide-clock',
    accent: 'text-amber-500',
  },
  {
    key: 'failed',
    label: t('CAMPAIGNS.STATISTICS.SUMMARY.FAILED'),
    value: formatNumber(props.summary.failed || 0),
    icon: 'i-lucide-alert-circle',
    accent: 'text-red-500',
  },
]);
</script>

<template>
  <div class="flex flex-col gap-3 mb-6">
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div
        v-for="card in heroCards"
        :key="card.key"
        class="relative flex flex-col gap-3 p-5 rounded-xl border border-n-border-glass-soft bg-n-glass-soft overflow-hidden hover:border-n-border-glass transition-colors"
      >
        <div
          class="absolute -top-6 -right-6 size-20 rounded-full opacity-60"
          :class="card.ring"
        />
        <div class="flex items-center justify-between relative">
          <span
            class="text-xs font-medium text-n-text-body/60 uppercase tracking-wide truncate"
          >
            {{ card.label }}
          </span>
          <span class="size-4 shrink-0" :class="[card.icon, card.accent]" />
        </div>
        <span
          class="text-2xl font-bold text-n-text-display tabular-nums relative leading-none"
        >
          {{ card.value }}
        </span>
      </div>
    </div>

    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div
        v-for="card in secondaryCards"
        :key="card.key"
        class="flex items-center gap-3 px-4 py-3 rounded-xl border border-n-border-glass-soft bg-n-glass-soft hover:border-n-border-glass transition-colors"
      >
        <div
          class="flex items-center justify-center size-9 rounded-lg bg-n-alpha-1"
        >
          <span class="size-4" :class="[card.icon, card.accent]" />
        </div>
        <div class="flex flex-col min-w-0">
          <span
            class="text-lg font-semibold text-n-text-display tabular-nums leading-tight"
          >
            {{ card.value }}
          </span>
          <span class="text-xs text-n-text-body/60 truncate">
            {{ card.label }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
