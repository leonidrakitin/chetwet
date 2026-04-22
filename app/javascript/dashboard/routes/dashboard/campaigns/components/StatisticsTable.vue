<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  campaigns: {
    type: Array,
    required: true,
  },
  statistics: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['selectCampaign']);

const { t } = useI18n();

const rows = computed(() =>
  props.campaigns
    .map(campaign => {
      const s = props.statistics[campaign.id] || {};
      const sent = s.sent || 0;
      const failed = s.failed || 0;
      const skipped = s.skipped || 0;
      const replied = s.replied || 0;
      const total = s.total || sent + failed + skipped + replied;
      const deliveryRate =
        s.delivery_rate ||
        (sent + failed > 0 ? ((sent / (sent + failed)) * 100).toFixed(1) : 0);
      const replyRate =
        s.reply_rate || (sent > 0 ? ((replied / sent) * 100).toFixed(1) : 0);

      return {
        id: campaign.id,
        name: campaign.name || campaign.title || `#${campaign.id}`,
        sent,
        failed,
        skipped,
        replied,
        total,
        deliveryRate,
        replyRate,
        uniqueRecipients: s.unique_recipients || 0,
        firstSentAt: s.first_sent_at,
        lastSentAt: s.last_sent_at,
        hasData: total > 0,
      };
    })
    .filter(row => row.hasData)
    .sort((a, b) => b.total - a.total)
);

const hasData = computed(() => rows.value.length > 0);

function formatDate(dateStr) {
  if (!dateStr) return '-';
  const date = new Date(dateStr);
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

function getReplyRateClass(rate) {
  const r = parseFloat(rate);
  if (r >= 20)
    return 'bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-300';
  if (r >= 10)
    return 'bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300';
  return 'bg-n-alpha-2 text-n-slate-10';
}

function getDeliveryRateClass(rate) {
  const r = parseFloat(rate);
  if (r >= 95) return 'text-green-600';
  if (r >= 80) return 'text-amber-600';
  return 'text-red-600';
}
</script>

<template>
  <div class="rounded-xl border border-n-weak bg-n-solid-1">
    <div class="px-6 py-4 border-b border-n-weak">
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ t('CAMPAIGNS.STATISTICS.TABLE.TITLE') }}
      </h3>
    </div>

    <div
      v-if="!hasData"
      class="flex flex-col items-center justify-center py-12 gap-3"
    >
      <span class="i-lucide-inbox size-8 text-n-slate-9" />
      <span class="text-sm text-n-slate-10">
        {{ t('CAMPAIGNS.STATISTICS.TABLE.NO_DATA') }}
      </span>
    </div>

    <div v-else class="overflow-x-auto">
      <table class="w-full">
        <thead>
          <tr class="border-b border-n-weak">
            <th
              class="text-left px-6 py-3 text-xs font-semibold text-n-slate-10 uppercase tracking-wider"
            >
              {{ t('CAMPAIGNS.STATISTICS.COLUMNS.CAMPAIGN') }}
            </th>
            <th
              class="text-right px-4 py-3 text-xs font-semibold text-n-slate-10 uppercase tracking-wider"
            >
              {{ t('CAMPAIGNS.STATISTICS.COLUMNS.SENT') }}
            </th>
            <th
              class="text-right px-4 py-3 text-xs font-semibold text-n-slate-10 uppercase tracking-wider"
            >
              {{ t('CAMPAIGNS.STATISTICS.COLUMNS.FAILED') }}
            </th>
            <th
              class="text-right px-4 py-3 text-xs font-semibold text-n-slate-10 uppercase tracking-wider hidden lg:table-cell"
            >
              {{ t('CAMPAIGNS.STATISTICS.COLUMNS.SKIPPED') }}
            </th>
            <th
              class="text-right px-4 py-3 text-xs font-semibold text-n-slate-10 uppercase tracking-wider hidden lg:table-cell"
            >
              {{ t('CAMPAIGNS.STATISTICS.COLUMNS.REPLIED') }}
            </th>
            <th
              class="text-right px-4 py-3 text-xs font-semibold text-n-slate-10 uppercase tracking-wider hidden md:table-cell"
            >
              {{ t('CAMPAIGNS.STATISTICS.COLUMNS.DELIVERY_RATE') }}
            </th>
            <th
              class="text-right px-4 py-3 text-xs font-semibold text-n-slate-10 uppercase tracking-wider"
            >
              {{ t('CAMPAIGNS.STATISTICS.COLUMNS.REPLY_RATE') }}
            </th>
            <th
              class="text-right px-6 py-3 text-xs font-semibold text-n-slate-10 uppercase tracking-wider hidden xl:table-cell"
            >
              {{ t('CAMPAIGNS.STATISTICS.COLUMNS.LAST_SENT') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-n-weak">
          <tr
            v-for="row in rows"
            :key="row.id"
            class="hover:bg-n-alpha-1 cursor-pointer transition-colors"
            @click="emit('selectCampaign', row.id)"
          >
            <td class="px-6 py-4">
              <span class="text-sm font-medium text-n-slate-12">{{
                row.name
              }}</span>
            </td>
            <td class="px-4 py-4 text-right">
              <span class="text-sm text-n-slate-11 tabular-nums">{{
                row.sent.toLocaleString()
              }}</span>
            </td>
            <td class="px-4 py-4 text-right">
              <span
                class="text-sm tabular-nums"
                :class="
                  row.failed > 0 ? 'text-red-600 font-medium' : 'text-n-slate-9'
                "
              >
                {{ row.failed }}
              </span>
            </td>
            <td class="px-4 py-4 text-right hidden lg:table-cell">
              <span class="text-sm text-n-slate-9 tabular-nums">{{
                row.skipped
              }}</span>
            </td>
            <td class="px-4 py-4 text-right hidden lg:table-cell">
              <span class="text-sm text-n-slate-11 tabular-nums">{{
                row.replied
              }}</span>
            </td>
            <td class="px-4 py-4 text-right hidden md:table-cell">
              <span
                class="text-sm font-medium tabular-nums"
                :class="getDeliveryRateClass(row.deliveryRate)"
              >
                {{ row.deliveryRate }}%
              </span>
            </td>
            <td class="px-4 py-4 text-right">
              <span
                class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
                :class="getReplyRateClass(row.replyRate)"
              >
                {{ row.replyRate }}%
              </span>
            </td>
            <td class="px-6 py-4 text-right hidden xl:table-cell">
              <span class="text-sm text-n-slate-9">{{
                formatDate(row.lastSentAt)
              }}</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
