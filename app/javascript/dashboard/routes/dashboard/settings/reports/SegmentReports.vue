<script setup>
/* global axios */
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import VueApexCharts from 'vue3-apexcharts';

const { t } = useI18n();
const store = useStore();
const accountId = computed(() => store.getters.getCurrentAccountId);

const loading = ref(true);
const errorMsg = ref(null);
const totalClients = ref(0);
const segments = ref([]);
const distribution = ref([]);

const isDarkMode = computed(
  () => document.documentElement.getAttribute('data-theme') === 'dark'
);

const donutOptions = computed(() => ({
  chart: {
    type: 'donut',
    background: 'transparent',
    fontFamily: 'inherit',
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
            color: isDarkMode.value ? '#94a3b8' : '#64748b',
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
    style: {
      fontSize: '11px',
      fontWeight: 500,
    },
    dropShadow: { enabled: false },
  },
  legend: {
    position: 'bottom',
    fontSize: '13px',
    labels: {
      colors: isDarkMode.value ? '#cbd5e1' : '#475569',
    },
    markers: { size: 5 },
  },
  tooltip: {
    y: {
      formatter: val =>
        `${val.toLocaleString('ru-RU')} ${t('SEGMENT_REPORTS.CLIENTS_SUFFIX')}`,
    },
  },
  theme: {
    mode: isDarkMode.value ? 'dark' : 'light',
  },
  stroke: {
    show: true,
    width: 2,
    colors: [isDarkMode.value ? '#1e293b' : '#ffffff'],
  },
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

const barOptions = computed(() => ({
  chart: {
    type: 'bar',
    background: 'transparent',
    toolbar: { show: false },
    fontFamily: 'inherit',
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
    style: {
      fontSize: '12px',
      fontWeight: 600,
      colors: ['#fff'],
    },
  },
  xaxis: {
    categories: segments.value.map(s => s.name),
    labels: {
      style: {
        colors: isDarkMode.value ? '#94a3b8' : '#64748b',
        fontSize: '12px',
      },
    },
  },
  yaxis: {
    labels: {
      style: {
        colors: isDarkMode.value ? '#cbd5e1' : '#475569',
        fontSize: '13px',
      },
    },
  },
  grid: {
    borderColor: isDarkMode.value ? '#334155' : '#e2e8f0',
    strokeDashArray: 4,
  },
  tooltip: {
    y: {
      formatter: val =>
        `${val.toLocaleString('ru-RU')} ${t('SEGMENT_REPORTS.CLIENTS_SUFFIX')}`,
    },
  },
  legend: { show: false },
  theme: {
    mode: isDarkMode.value ? 'dark' : 'light',
  },
}));

const barSeries = computed(() => [
  {
    name: t('SEGMENT_REPORTS.CLIENTS_SUFFIX'),
    data: segments.value.map(s => s.count),
  },
]);

async function fetchData() {
  loading.value = true;
  errorMsg.value = null;
  try {
    const response = await axios.get(
      `/api/v1/accounts/${accountId.value}/segment_reports/summary`
    );
    totalClients.value = response.data.total_clients;
    segments.value = response.data.segments;
    distribution.value = response.data.distribution;
  } catch {
    errorMsg.value = t('SEGMENT_REPORTS.ERROR');
  } finally {
    loading.value = false;
  }
}

onMounted(fetchData);
</script>

<template>
  <div class="flex flex-col gap-6 py-6">
    <div class="flex items-center justify-between">
      <h1 class="text-2xl font-bold text-n-slate-12">
        {{ $t('SEGMENT_REPORTS.TITLE') }}
      </h1>
      <button
        class="flex items-center gap-2 rounded-xl bg-n-brand px-4 py-2 text-sm font-medium text-white transition hover:opacity-90"
        @click="fetchData"
      >
        <fluent-icon icon="arrow-clockwise" size="14" />
        {{ $t('SEGMENT_REPORTS.REFRESH') }}
      </button>
    </div>

    <div
      v-if="loading"
      class="flex items-center justify-center rounded-xl bg-n-solid-2 p-12 shadow outline outline-1 outline-n-container"
    >
      <span class="spinner" />
      <span class="ml-3 text-sm text-n-slate-11">
        {{ $t('SEGMENT_REPORTS.LOADING') }}
      </span>
    </div>

    <div
      v-else-if="errorMsg"
      class="flex flex-col items-center gap-3 rounded-xl bg-n-solid-2 p-12 shadow outline outline-1 outline-n-container"
    >
      <p class="text-sm text-n-ruby-11">
        {{ errorMsg }}
      </p>
      <button
        class="rounded-lg bg-n-brand px-4 py-2 text-sm text-white hover:opacity-90"
        @click="fetchData"
      >
        {{ $t('SEGMENT_REPORTS.RETRY') }}
      </button>
    </div>

    <template v-else>
      <div class="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5">
        <div
          v-for="seg in segments"
          :key="seg.name"
          class="flex flex-col gap-1 rounded-xl bg-n-solid-2 px-4 py-4 shadow outline outline-1 outline-n-container"
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
        </div>
      </div>

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
    </template>
  </div>
</template>
