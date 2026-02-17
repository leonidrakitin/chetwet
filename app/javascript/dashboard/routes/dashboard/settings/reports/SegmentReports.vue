<script setup>
/* global axios */
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import VueApexCharts from 'vue3-apexcharts';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const store = useStore();
const accountId = computed(() => store.getters.getCurrentAccountId);

// State
const loading = ref(true);
const errorMsg = ref(null);
const totalClients = ref(0);
const totalRevenue = ref(0);
const segments = ref([]);
const distribution = ref([]);

// Details modal
const showDetails = ref(false);
const detailsLoading = ref(false);
const detailsError = ref(null);
const detailsData = ref(null);
const detailsPage = ref(1);

// Trends
const trendsData = ref([]);
const trendsSegmentNames = ref([]);
const trendsLoading = ref(false);

// Date filter
const DATE_RANGES = [
  { id: 'last_30_days', label: t('SEGMENT_REPORTS.LAST_30_DAYS'), months: 1 },
  { id: 'last_90_days', label: t('SEGMENT_REPORTS.LAST_90_DAYS'), months: 3 },
  { id: 'last_year', label: t('SEGMENT_REPORTS.LAST_YEAR'), months: 12 },
];
const selectedRange = ref('last_90_days');

const isDarkMode = computed(
  () => document.documentElement.getAttribute('data-theme') === 'dark'
);

const themeMode = computed(() => (isDarkMode.value ? 'dark' : 'light'));
const textColor = computed(() => (isDarkMode.value ? '#cbd5e1' : '#475569'));
const labelColor = computed(() => (isDarkMode.value ? '#94a3b8' : '#64748b'));
const gridColor = computed(() => (isDarkMode.value ? '#334155' : '#e2e8f0'));
const strokeColors = computed(() => [isDarkMode.value ? '#1e293b' : '#ffffff']);

function formatRub(val) {
  return `${Number(val).toLocaleString('ru-RU')} ${t('SEGMENT_REPORTS.RUB_SUFFIX')}`;
}

// API base
const apiBase = computed(
  () => `/api/v1/accounts/${accountId.value}/segment_reports`
);

// Details functions (defined early to avoid use-before-define)
async function loadDetailsPage(segmentName, page) {
  detailsLoading.value = true;
  detailsError.value = null;
  try {
    const name = segmentName || detailsData.value?.segment_name;
    const response = await axios.get(
      `${apiBase.value}/details/${encodeURIComponent(name)}`,
      { params: { page, per_page: 20 } }
    );
    detailsData.value = response.data;
    detailsPage.value = page;
  } catch {
    detailsError.value = t('SEGMENT_REPORTS.DETAILS.ERROR');
  } finally {
    detailsLoading.value = false;
  }
}

async function openDetails(segmentName) {
  detailsPage.value = 1;
  detailsData.value = null;
  detailsError.value = null;
  showDetails.value = true;
  await loadDetailsPage(segmentName, 1);
}

// Donut chart
const donutOptions = computed(() => ({
  chart: {
    type: 'donut',
    background: 'transparent',
    fontFamily: 'inherit',
    events: {
      dataPointSelection: (_e, _chart, config) => {
        const seg = segments.value[config.dataPointIndex];
        if (seg) openDetails(seg.name);
      },
    },
  },
  labels: distribution.value.map(d => d.name),
  colors: distribution.value.map(d => d.color),
  plotOptions: {
    pie: {
      donut: {
        size: '65%',
        labels: {
          show: true,
          name: {
            show: true,
            fontSize: '14px',
            color: isDarkMode.value ? '#e2e8f0' : '#334155',
          },
          value: {
            show: true,
            fontSize: '24px',
            fontWeight: 700,
            color: isDarkMode.value ? '#f1f5f9' : '#1e293b',
          },
          total: {
            show: true,
            label: t('SEGMENT_REPORTS.TOTAL_CLIENTS'),
            fontSize: '12px',
            color: labelColor.value,
            formatter: () => totalClients.value.toLocaleString('ru-RU'),
          },
        },
      },
    },
  },
  dataLabels: {
    enabled: true,
    formatter: (val, opts) => {
      const name = opts.w.globals.labels[opts.seriesIndex];
      return `${name}: ${val.toFixed(1)}%`;
    },
    style: { fontSize: '11px', fontWeight: 500 },
    dropShadow: { enabled: false },
  },
  legend: {
    position: 'bottom',
    fontSize: '13px',
    labels: { colors: textColor.value },
    markers: { size: 5 },
  },
  tooltip: {
    y: {
      formatter: val =>
        `${val.toLocaleString('ru-RU')} ${t('SEGMENT_REPORTS.CLIENTS_SUFFIX')}`,
    },
  },
  theme: { mode: themeMode.value },
  stroke: { show: true, width: 2, colors: strokeColors.value },
  responsive: [
    {
      breakpoint: 640,
      options: {
        chart: { height: 300 },
        legend: { position: 'bottom', fontSize: '11px' },
        dataLabels: { enabled: false },
      },
    },
  ],
}));
const donutSeries = computed(() => segments.value.map(s => s.count));

// Clients bar chart
const barOptions = computed(() => ({
  chart: {
    type: 'bar',
    background: 'transparent',
    toolbar: { show: false },
    fontFamily: 'inherit',
    events: {
      dataPointSelection: (_e, _chart, config) => {
        const seg = segments.value[config.dataPointIndex];
        if (seg) openDetails(seg.name);
      },
    },
  },
  plotOptions: {
    bar: {
      horizontal: true,
      borderRadius: 6,
      barHeight: '60%',
      distributed: true,
    },
  },
  colors: segments.value.map(s => s.color),
  dataLabels: {
    enabled: true,
    formatter: val => val.toLocaleString('ru-RU'),
    style: { fontSize: '12px', fontWeight: 600, colors: ['#fff'] },
  },
  xaxis: {
    categories: segments.value.map(s => s.name),
    labels: { style: { colors: labelColor.value, fontSize: '12px' } },
  },
  yaxis: {
    labels: { style: { colors: textColor.value, fontSize: '13px' } },
  },
  grid: { borderColor: gridColor.value, strokeDashArray: 4 },
  tooltip: {
    y: {
      formatter: val =>
        `${val.toLocaleString('ru-RU')} ${t('SEGMENT_REPORTS.CLIENTS_SUFFIX')}`,
    },
  },
  legend: { show: false },
  theme: { mode: themeMode.value },
}));
const barSeries = computed(() => [
  {
    name: t('SEGMENT_REPORTS.CLIENTS_SUFFIX'),
    data: segments.value.map(s => s.count),
  },
]);

// Revenue bar chart
const revenueBarOptions = computed(() => ({
  chart: {
    type: 'bar',
    background: 'transparent',
    toolbar: { show: false },
    fontFamily: 'inherit',
    events: {
      dataPointSelection: (_e, _chart, config) => {
        const seg = segments.value[config.dataPointIndex];
        if (seg) openDetails(seg.name);
      },
    },
  },
  plotOptions: {
    bar: {
      horizontal: true,
      borderRadius: 6,
      barHeight: '60%',
      distributed: true,
    },
  },
  colors: segments.value.map(s => s.color),
  dataLabels: {
    enabled: true,
    formatter: val => formatRub(val),
    style: { fontSize: '11px', fontWeight: 600, colors: ['#fff'] },
  },
  xaxis: {
    categories: segments.value.map(s => s.name),
    labels: {
      style: { colors: labelColor.value, fontSize: '12px' },
      formatter: val => formatRub(val),
    },
  },
  yaxis: {
    labels: { style: { colors: textColor.value, fontSize: '13px' } },
  },
  grid: { borderColor: gridColor.value, strokeDashArray: 4 },
  tooltip: { y: { formatter: val => formatRub(val) } },
  legend: { show: false },
  theme: { mode: themeMode.value },
}));
const revenueSeries = computed(() => [
  {
    name: t('SEGMENT_REPORTS.REVENUE_LABEL'),
    data: segments.value.map(s => s.revenue),
  },
]);

// Trends line chart
const SEGMENT_COLORS = {
  Лояльные: '#4CAF50',
  Новички: '#2196F3',
  'В зоне риска': '#FF9800',
  'Ближайшие потери': '#F44336',
  Прочие: '#9C27B0',
};
const trendsOptions = computed(() => ({
  chart: {
    type: 'line',
    background: 'transparent',
    toolbar: { show: false },
    fontFamily: 'inherit',
    zoom: { enabled: false },
  },
  colors: trendsSegmentNames.value.map(n => SEGMENT_COLORS[n] || '#666'),
  stroke: { width: 2, curve: 'smooth' },
  xaxis: {
    categories: trendsData.value.map(d => d.month),
    labels: { style: { colors: labelColor.value, fontSize: '11px' } },
  },
  yaxis: {
    labels: {
      style: { colors: textColor.value, fontSize: '12px' },
      formatter: val => val.toLocaleString('ru-RU'),
    },
  },
  grid: { borderColor: gridColor.value, strokeDashArray: 4 },
  legend: {
    position: 'bottom',
    fontSize: '12px',
    labels: { colors: textColor.value },
  },
  tooltip: {
    y: {
      formatter: val =>
        `${val.toLocaleString('ru-RU')} ${t('SEGMENT_REPORTS.CLIENTS_SUFFIX')}`,
    },
  },
  theme: { mode: themeMode.value },
}));
const trendsSeries = computed(() =>
  trendsSegmentNames.value.map(name => ({
    name,
    data: trendsData.value.map(d => d[name] || 0),
  }))
);

// Remaining API functions
async function fetchData() {
  loading.value = true;
  errorMsg.value = null;
  try {
    const response = await axios.get(`${apiBase.value}/summary`);
    totalClients.value = response.data.total_clients;
    totalRevenue.value = response.data.total_revenue;
    segments.value = response.data.segments;
    distribution.value = response.data.distribution;
  } catch {
    errorMsg.value = t('SEGMENT_REPORTS.ERROR');
  } finally {
    loading.value = false;
  }
}

async function fetchTrends() {
  trendsLoading.value = true;
  const range = DATE_RANGES.find(r => r.id === selectedRange.value);
  try {
    const response = await axios.get(`${apiBase.value}/trends`, {
      params: { months: range?.months || 6 },
    });
    trendsData.value = response.data.trends;
    trendsSegmentNames.value = response.data.segment_names;
  } catch {
    // Trends are non-critical
  } finally {
    trendsLoading.value = false;
  }
}

function closeDetails() {
  showDetails.value = false;
  detailsData.value = null;
}

async function exportCsv() {
  if (!detailsData.value) return;
  try {
    const response = await axios.get(
      `${apiBase.value}/export/${encodeURIComponent(detailsData.value.segment_name)}`,
      { responseType: 'blob' }
    );
    const url = URL.createObjectURL(response.data);
    const link = document.createElement('a');
    link.href = url;
    link.download = `segment_${detailsData.value.segment_name}_${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  } catch {
    // Export error silently ignored
  }
}

function onRangeChange() {
  fetchData();
  fetchTrends();
}

onMounted(() => {
  fetchData();
  fetchTrends();
});
</script>

<template>
  <div class="flex flex-col gap-6 py-6">
    <!-- Header with filters -->
    <div
      class="flex flex-col gap-4 rounded-xl bg-n-solid-2 px-6 py-4 shadow outline outline-1 outline-n-container sm:flex-row sm:items-center sm:justify-between"
    >
      <h1 class="text-xl font-bold text-n-slate-12">
        {{ $t('SEGMENT_REPORTS.TITLE') }}
      </h1>
      <div class="flex items-center gap-2">
        <select
          v-model="selectedRange"
          class="h-9 cursor-pointer appearance-none rounded-lg border border-n-weak bg-n-solid-2 px-3 pr-8 text-sm font-medium text-n-slate-12 outline-none transition hover:border-n-brand focus:border-n-brand focus:ring-1 focus:ring-n-brand"
          @change="onRangeChange"
        >
          <option
            v-for="range in DATE_RANGES"
            :key="range.id"
            :value="range.id"
          >
            {{ range.label }}
          </option>
        </select>
        <Button
          icon="i-lucide-refresh-cw"
          :label="$t('SEGMENT_REPORTS.REFRESH')"
          size="sm"
          variant="faded"
          color="slate"
          @click="onRangeChange"
        />
      </div>
    </div>

    <!-- Loading -->
    <div
      v-if="loading"
      class="flex items-center justify-center rounded-xl bg-n-solid-2 p-12 shadow outline outline-1 outline-n-container"
    >
      <Spinner />
      <span class="ml-3 text-sm text-n-slate-11">
        {{ $t('SEGMENT_REPORTS.LOADING') }}
      </span>
    </div>

    <!-- Error -->
    <div
      v-else-if="errorMsg"
      class="flex flex-col items-center gap-3 rounded-xl bg-n-solid-2 p-12 shadow outline outline-1 outline-n-container"
    >
      <p class="text-sm text-n-ruby-11">
        {{ errorMsg }}
      </p>
      <Button :label="$t('SEGMENT_REPORTS.RETRY')" @click="onRangeChange" />
    </div>

    <!-- Content -->
    <template v-else>
      <!-- Summary cards -->
      <div class="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-6">
        <!-- Total card -->
        <div
          class="flex flex-col gap-1 rounded-xl bg-n-solid-2 px-4 py-4 shadow outline outline-1 outline-n-container"
        >
          <span class="text-xs font-medium text-n-slate-11">
            {{ $t('SEGMENT_REPORTS.TOTAL_CLIENTS') }}
          </span>
          <span class="text-xl font-bold text-n-slate-12">
            {{ totalClients.toLocaleString('ru-RU') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ formatRub(totalRevenue) }}
          </span>
        </div>

        <!-- Segment cards -->
        <div
          v-for="seg in segments"
          :key="seg.name"
          class="flex cursor-pointer flex-col gap-1 rounded-xl bg-n-solid-2 px-4 py-4 shadow outline outline-1 outline-n-container transition hover:outline-n-brand"
          @click="openDetails(seg.name)"
        >
          <div class="flex items-center gap-2">
            <span
              class="inline-block size-3 rounded-full"
              :style="{ backgroundColor: seg.color }"
            />
            <span class="text-xs font-medium text-n-slate-11">
              {{ seg.name }}
            </span>
          </div>
          <span class="text-xl font-bold text-n-slate-12">
            {{ seg.count.toLocaleString('ru-RU') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ formatRub(seg.revenue) }}
          </span>
        </div>
      </div>

      <!-- Charts row 1: Donut + Clients bar -->
      <div class="grid gap-6 lg:grid-cols-2">
        <div
          class="flex flex-col rounded-xl bg-n-solid-2 p-6 shadow outline outline-1 outline-n-container"
        >
          <h2 class="mb-4 text-base font-semibold text-n-slate-12">
            {{ $t('SEGMENT_REPORTS.DONUT_TITLE') }}
          </h2>
          <VueApexCharts
            type="donut"
            height="380"
            :options="donutOptions"
            :series="donutSeries"
          />
        </div>

        <div
          class="flex flex-col rounded-xl bg-n-solid-2 p-6 shadow outline outline-1 outline-n-container"
        >
          <h2 class="mb-4 text-base font-semibold text-n-slate-12">
            {{ $t('SEGMENT_REPORTS.BAR_TITLE') }}
          </h2>
          <VueApexCharts
            type="bar"
            height="380"
            :options="barOptions"
            :series="barSeries"
          />
        </div>
      </div>

      <!-- Charts row 2: Revenue bar -->
      <div
        class="flex flex-col rounded-xl bg-n-solid-2 p-6 shadow outline outline-1 outline-n-container"
      >
        <h2 class="mb-4 text-base font-semibold text-n-slate-12">
          {{ $t('SEGMENT_REPORTS.REVENUE_BAR_TITLE') }}
        </h2>
        <VueApexCharts
          type="bar"
          height="320"
          :options="revenueBarOptions"
          :series="revenueSeries"
        />
      </div>

      <!-- Trends line chart -->
      <div
        class="flex flex-col rounded-xl bg-n-solid-2 p-6 shadow outline outline-1 outline-n-container"
      >
        <h2 class="mb-4 text-base font-semibold text-n-slate-12">
          {{ $t('SEGMENT_REPORTS.TRENDS_TITLE') }}
        </h2>
        <div
          v-if="trendsLoading"
          class="flex items-center justify-center py-12"
        >
          <Spinner />
        </div>
        <VueApexCharts
          v-else-if="trendsData.length"
          type="line"
          height="320"
          :options="trendsOptions"
          :series="trendsSeries"
        />
      </div>
    </template>

    <!-- Details modal -->
    <woot-modal v-model:show="showDetails" :on-close="closeDetails">
      <div class="flex max-h-[80vh] flex-col overflow-hidden">
        <woot-modal-header
          :header-title="
            detailsData
              ? `${$t('SEGMENT_REPORTS.DETAILS.TITLE')}: ${detailsData.segment_name}`
              : $t('SEGMENT_REPORTS.DETAILS.TITLE')
          "
        />

        <!-- Details loading -->
        <div
          v-if="detailsLoading && !detailsData"
          class="flex items-center justify-center p-12"
        >
          <Spinner />
          <span class="ml-3 text-sm text-n-slate-11">
            {{ $t('SEGMENT_REPORTS.DETAILS.LOADING') }}
          </span>
        </div>

        <!-- Details error -->
        <div
          v-else-if="detailsError && !detailsData"
          class="p-8 text-center text-sm text-n-ruby-11"
        >
          {{ detailsError }}
        </div>

        <!-- Details content -->
        <div
          v-else-if="detailsData"
          class="flex flex-col gap-5 overflow-y-auto px-8 pb-8"
        >
          <!-- Criteria -->
          <div>
            <h3 class="mb-1 text-sm font-semibold text-n-slate-12">
              {{ $t('SEGMENT_REPORTS.DETAILS.CRITERIA') }}
            </h3>
            <p class="text-sm text-n-slate-11">
              {{ detailsData.criteria }}
            </p>
          </div>

          <!-- Recent changes + Avg metrics -->
          <div class="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5">
            <div
              class="flex flex-col gap-0.5 rounded-lg bg-n-alpha-3 px-3 py-3"
            >
              <span class="text-xs text-n-slate-11">
                {{ $t('SEGMENT_REPORTS.DETAILS.JOINED') }}
              </span>
              <span class="text-lg font-bold text-n-teal-11">
                +{{ detailsData.recent_changes.joined }}
              </span>
            </div>
            <div
              class="flex flex-col gap-0.5 rounded-lg bg-n-alpha-3 px-3 py-3"
            >
              <span class="text-xs text-n-slate-11">
                {{ $t('SEGMENT_REPORTS.DETAILS.LEFT') }}
              </span>
              <span class="text-lg font-bold text-n-ruby-11">
                -{{ detailsData.recent_changes.left }}
              </span>
            </div>
            <div
              class="flex flex-col gap-0.5 rounded-lg bg-n-alpha-3 px-3 py-3"
            >
              <span class="text-xs text-n-slate-11">
                {{ $t('SEGMENT_REPORTS.DETAILS.AVG_CHECK') }}
              </span>
              <span class="text-lg font-bold text-n-slate-12">
                {{ formatRub(detailsData.avg_metrics.avg_check) }}
              </span>
            </div>
            <div
              class="flex flex-col gap-0.5 rounded-lg bg-n-alpha-3 px-3 py-3"
            >
              <span class="text-xs text-n-slate-11">
                {{ $t('SEGMENT_REPORTS.DETAILS.AVG_RECENCY') }}
              </span>
              <span class="text-lg font-bold text-n-slate-12">
                {{ detailsData.avg_metrics.avg_recency_days }}
              </span>
            </div>
            <div
              class="flex flex-col gap-0.5 rounded-lg bg-n-alpha-3 px-3 py-3"
            >
              <span class="text-xs text-n-slate-11">
                {{ $t('SEGMENT_REPORTS.DETAILS.AVG_PURCHASES') }}
              </span>
              <span class="text-lg font-bold text-n-slate-12">
                {{ detailsData.avg_metrics.avg_purchase_count }}
              </span>
            </div>
          </div>

          <!-- Clients table -->
          <div>
            <div class="mb-2 flex items-center justify-between">
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ $t('SEGMENT_REPORTS.DETAILS.CLIENTS_TABLE') }}
                ({{ detailsData.total_clients_in_segment }})
              </h3>
              <Button
                icon="i-lucide-download"
                :label="$t('SEGMENT_REPORTS.EXPORT_CSV')"
                size="sm"
                variant="faded"
                color="slate"
                @click="exportCsv"
              />
            </div>

            <div
              v-if="detailsData.clients.length"
              class="overflow-x-auto rounded-lg border border-n-weak"
            >
              <table class="w-full min-w-[36rem]">
                <thead class="bg-n-alpha-3">
                  <tr>
                    <th
                      class="px-4 py-2.5 text-left text-xs font-medium text-n-slate-11"
                    >
                      {{ $t('SEGMENT_REPORTS.DETAILS.COL_NAME') }}
                    </th>
                    <th
                      class="px-4 py-2.5 text-right text-xs font-medium text-n-slate-11"
                    >
                      {{ $t('SEGMENT_REPORTS.DETAILS.COL_PURCHASES') }}
                    </th>
                    <th
                      class="px-4 py-2.5 text-right text-xs font-medium text-n-slate-11"
                    >
                      {{ $t('SEGMENT_REPORTS.DETAILS.COL_LAST_PURCHASE') }}
                    </th>
                    <th
                      class="px-4 py-2.5 text-right text-xs font-medium text-n-slate-11"
                    >
                      {{ $t('SEGMENT_REPORTS.DETAILS.COL_TOTAL_SPENT') }}
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-n-weak">
                  <tr
                    v-for="client in detailsData.clients"
                    :key="client.id"
                    class="hover:bg-n-alpha-1"
                  >
                    <td class="px-4 py-2.5 text-sm text-n-slate-12">
                      {{ client.name }}
                    </td>
                    <td class="px-4 py-2.5 text-right text-sm text-n-slate-12">
                      {{ client.purchase_count }}
                    </td>
                    <td class="px-4 py-2.5 text-right text-sm text-n-slate-11">
                      {{ client.last_purchase || '—' }}
                    </td>
                    <td
                      class="px-4 py-2.5 text-right text-sm font-medium text-n-slate-12"
                    >
                      {{ formatRub(client.total_spent) }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <p v-else class="py-4 text-center text-sm text-n-slate-11">
              {{ $t('SEGMENT_REPORTS.DETAILS.NO_CLIENTS') }}
            </p>

            <!-- Pagination -->
            <div
              v-if="
                detailsData.pagination && detailsData.pagination.total_pages > 1
              "
              class="mt-3 flex items-center justify-center gap-2"
            >
              <Button
                size="xs"
                variant="faded"
                color="slate"
                icon="i-lucide-chevron-left"
                :disabled="detailsPage <= 1"
                @click="
                  loadDetailsPage(detailsData.segment_name, detailsPage - 1)
                "
              />
              <span class="text-sm text-n-slate-11">
                {{ $t('SEGMENT_REPORTS.DETAILS.PAGE') }}
                {{ detailsPage }} / {{ detailsData.pagination.total_pages }}
              </span>
              <Button
                size="xs"
                variant="faded"
                color="slate"
                icon="i-lucide-chevron-right"
                :disabled="detailsPage >= detailsData.pagination.total_pages"
                @click="
                  loadDetailsPage(detailsData.segment_name, detailsPage + 1)
                "
              />
            </div>
          </div>

          <!-- Notifications -->
          <div v-if="detailsData.notifications.length">
            <h3 class="mb-2 text-sm font-semibold text-n-slate-12">
              {{ $t('SEGMENT_REPORTS.DETAILS.NOTIFICATIONS') }}
            </h3>
            <ul class="flex flex-col gap-2">
              <li
                v-for="(notif, idx) in detailsData.notifications"
                :key="idx"
                class="flex items-center gap-3 rounded-lg bg-n-alpha-3 px-3 py-2"
              >
                <span
                  class="rounded bg-n-alpha-5 px-2 py-0.5 text-xs font-medium uppercase text-n-slate-11"
                >
                  {{ notif.type }}
                </span>
                <span class="text-sm text-n-slate-12">
                  {{ notif.subject }}
                </span>
                <span class="ml-auto text-xs text-n-slate-11">
                  {{ notif.sent_at }}
                </span>
              </li>
            </ul>
          </div>

          <!-- Suggestions -->
          <div v-if="detailsData.improvement_suggestions.length">
            <h3 class="mb-2 text-sm font-semibold text-n-slate-12">
              {{ $t('SEGMENT_REPORTS.DETAILS.SUGGESTIONS') }}
            </h3>
            <ul class="flex flex-col gap-1.5">
              <li
                v-for="(suggestion, idx) in detailsData.improvement_suggestions"
                :key="idx"
                class="flex items-start gap-2 text-sm text-n-slate-11"
              >
                <span
                  class="mt-1 inline-block size-1.5 flex-shrink-0 rounded-full bg-n-brand"
                />
                {{ suggestion }}
              </li>
            </ul>
          </div>
        </div>
      </div>
    </woot-modal>
  </div>
</template>
