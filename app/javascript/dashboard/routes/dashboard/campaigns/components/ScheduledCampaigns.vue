<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  campaigns: {
    type: Array,
    required: true,
  },
  loading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['edit', 'delete']);

const { t } = useI18n();

const scheduledCampaigns = computed(() =>
  props.campaigns
    .filter(c => c.scheduled_at && new Date(c.scheduled_at) > new Date())
    .sort((a, b) => new Date(a.scheduled_at) - new Date(b.scheduled_at))
);

const hasScheduled = computed(() => scheduledCampaigns.value.length > 0);

function formatScheduledAt(dateStr) {
  if (!dateStr) return '';
  const date = new Date(dateStr);
  const now = new Date();
  const diffMs = date - now;
  const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
  const diffDays = Math.floor(diffHours / 24);

  if (diffDays > 0) {
    return t('CAMPAIGNS.STATISTICS.SCHEDULED.IN_DAYS', {
      days: diffDays,
      time: date.toLocaleTimeString('en-US', {
        hour: '2-digit',
        minute: '2-digit',
      }),
    });
  }
  if (diffHours > 0) {
    return t('CAMPAIGNS.STATISTICS.SCHEDULED.IN_HOURS', { hours: diffHours });
  }
  return t('CAMPAIGNS.STATISTICS.SCHEDULED.SOON');
}

function formatFullDate(dateStr) {
  if (!dateStr) return '';
  const date = new Date(dateStr);
  return date.toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}
</script>

<template>
  <div
    v-if="hasScheduled"
    class="rounded-xl border border-n-border-glass-soft bg-n-glass-soft mb-6 overflow-hidden"
  >
    <div
      class="px-5 py-3 border-b border-n-border-glass-soft flex items-center gap-2"
    >
      <span
        class="flex items-center justify-center size-7 rounded-lg bg-amber-500/10 text-amber-600 dark:text-amber-400"
      >
        <span class="i-lucide-clock size-4" />
      </span>
      <h3 class="text-sm font-semibold text-n-text-display">
        {{
          t('CAMPAIGNS.STATISTICS.SCHEDULED.TITLE', {
            count: scheduledCampaigns.length,
          })
        }}
      </h3>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-8">
      <span class="i-lucide-loader-2 size-5 text-n-slate-9 animate-spin" />
    </div>

    <div v-else class="divide-y divide-n-border-glass-soft">
      <div
        v-for="campaign in scheduledCampaigns"
        :key="campaign.id"
        class="flex items-center justify-between px-5 py-3 hover:bg-n-alpha-1 transition-colors"
      >
        <div class="flex items-center gap-3 min-w-0">
          <span
            class="size-2 rounded-full shrink-0"
            :class="campaign.enabled ? 'bg-green-500' : 'bg-n-slate-8'"
          />
          <div class="min-w-0">
            <span class="text-sm font-medium text-n-text-display truncate">
              {{ campaign.name }}
            </span>
            <span
              v-if="campaign.inbox_name"
              class="text-xs text-n-text-body/60 ml-2"
            >
              ({{ campaign.inbox_name }})
            </span>
          </div>
        </div>

        <div class="flex items-center gap-4 shrink-0">
          <div class="text-right">
            <div class="text-sm font-medium text-n-text-display tabular-nums">
              {{ formatScheduledAt(campaign.scheduled_at) }}
            </div>
            <div class="text-xs text-n-slate-9 tabular-nums">
              {{ formatFullDate(campaign.scheduled_at) }}
            </div>
          </div>

          <div class="flex items-center gap-1">
            <button
              class="p-1.5 rounded-lg hover:bg-n-alpha-2 text-n-text-body hover:text-n-text-display transition-colors"
              :title="t('CAMPAIGNS.STATISTICS.SCHEDULED.EDIT')"
              @click="emit('edit', campaign)"
            >
              <span class="i-lucide-pencil size-4" />
            </button>
            <button
              class="p-1.5 rounded-lg hover:bg-red-500/10 text-n-text-body hover:text-red-600 dark:hover:text-red-400 transition-colors"
              :title="t('CAMPAIGNS.STATISTICS.SCHEDULED.CANCEL')"
              @click="emit('delete', campaign)"
            >
              <span class="i-lucide-x size-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
