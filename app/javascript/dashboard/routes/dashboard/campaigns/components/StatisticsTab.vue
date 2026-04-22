<script setup>
import { computed, ref, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import StatisticsSummary from './StatisticsSummary.vue';
import StatisticsChart from './StatisticsChart.vue';
import StatisticsTable from './StatisticsTable.vue';
import ScheduledCampaigns from './ScheduledCampaigns.vue';

const { t } = useI18n();
const store = useStore();

const selectedPeriod = ref('30d');
const periods = [
  { key: '7d', label: t('CAMPAIGNS.STATISTICS.PERIOD.7D') },
  { key: '14d', label: t('CAMPAIGNS.STATISTICS.PERIOD.14D') },
  { key: '30d', label: t('CAMPAIGNS.STATISTICS.PERIOD.30D') },
  { key: '90d', label: t('CAMPAIGNS.STATISTICS.PERIOD.90D') },
];

const uiFlags = computed(() => store.getters['campaigns/getUIFlags']);
const campaigns = computed(() => store.getters['campaigns/getCampaigns']);
const statistics = computed(() => store.getters['campaigns/getStatistics']);
const summary = computed(() => store.getters['campaigns/getStatisticsSummary']);
const timeSeries = computed(() => store.getters['campaigns/getTimeSeries']);
const scheduledCampaigns = computed(
  () => store.getters['campaigns/getScheduledCampaigns']
);

const isLoading = computed(() => uiFlags.value.isFetchingStatistics);

onMounted(() => {
  // campaigns/get runs from Index; do not dispatch it here — isFetching would hide this tab and remount in a loop.
  store.dispatch('campaigns/fetchStatistics', selectedPeriod.value);
});

watch(selectedPeriod, newPeriod => {
  store.dispatch('campaigns/fetchStatistics', newPeriod);
});

const handleEditCampaign = campaign => {
  store.dispatch('campaigns/update', {
    id: campaign.id,
    scheduled_at: null,
  });
};

const handleDeleteCampaign = campaign => {
  if (window.confirm(t('CAMPAIGNS.DELETE_CONFIRM'))) {
    store.dispatch('campaigns/delete', campaign.id);
  }
};

const handleSelectCampaign = () => {
  // no-op: row click is a placeholder for future detail navigation
};
</script>

<template>
  <div class="max-w-7xl mx-auto py-2">
    <div
      v-if="isLoading"
      class="flex items-center justify-center py-16 gap-3 text-n-slate-9"
    >
      <span class="i-lucide-loader-2 size-5 animate-spin" />
      <span class="text-sm">{{ t('CAMPAIGNS.STATISTICS.LOADING') }}</span>
    </div>

    <template v-else>
      <div
        class="flex flex-col sm:flex-row sm:items-end justify-between gap-4 mb-6"
      >
        <div class="flex items-start gap-3 min-w-0">
          <div
            class="flex items-center justify-center size-10 rounded-xl bg-n-brand/10 text-n-brand shrink-0"
          >
            <span class="i-lucide-bar-chart-3 size-5" />
          </div>
          <div class="min-w-0">
            <h2 class="text-xl font-semibold text-n-slate-12 leading-tight">
              {{ t('CAMPAIGNS.STATISTICS.TITLE') }}
            </h2>
            <p class="text-sm text-n-slate-10 mt-1">
              {{ t('CAMPAIGNS.STATISTICS.SUBTITLE') }}
            </p>
          </div>
        </div>

        <div
          class="inline-flex items-center gap-0.5 rounded-lg border border-n-weak bg-n-alpha-1 p-0.5 self-start sm:self-auto shrink-0"
        >
          <button
            v-for="period in periods"
            :key="period.key"
            class="px-3 py-1.5 text-xs font-medium rounded-md transition-colors"
            :class="
              selectedPeriod === period.key
                ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
                : 'text-n-slate-10 hover:text-n-slate-12'
            "
            @click="selectedPeriod = period.key"
          >
            {{ period.label }}
          </button>
        </div>
      </div>

      <StatisticsSummary :summary="summary" />

      <ScheduledCampaigns
        :campaigns="scheduledCampaigns"
        :loading="isLoading"
        @edit="handleEditCampaign"
        @delete="handleDeleteCampaign"
      />

      <StatisticsChart :time-series="timeSeries" :loading="isLoading" />

      <StatisticsTable
        :campaigns="campaigns"
        :statistics="statistics"
        @select-campaign="handleSelectCampaign"
      />
    </template>
  </div>
</template>
