<script setup>
import { computed, ref, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  timeSeries: {
    type: Object,
    required: true,
  },
  loading: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();

const selectedMetric = ref('deliveries');
const metrics = [
  { key: 'deliveries', label: t('CAMPAIGNS.STATISTICS.CHART.DELIVERIES') },
  { key: 'replies', label: t('CAMPAIGNS.STATISTICS.CHART.REPLIES') },
];

const chartData = computed(() => {
  const data = props.timeSeries[selectedMetric.value] || [];
  if (selectedMetric.value === 'deliveries') {
    return {
      labels: data.map(d => d.date),
      datasets: [
        {
          label: t('CAMPAIGNS.STATISTICS.COLUMNS.SENT'),
          data: data.map(d => d.sent),
          color: '#3b82f6',
        },
        {
          label: t('CAMPAIGNS.STATISTICS.COLUMNS.FAILED'),
          data: data.map(d => d.failed),
          color: '#ef4444',
        },
        {
          label: t('CAMPAIGNS.STATISTICS.COLUMNS.REPLIED'),
          data: data.map(d => d.replied),
          color: '#14b8a6',
        },
      ],
    };
  }
  return {
    labels: data.map(d => d.date),
    datasets: [
      {
        label: t('CAMPAIGNS.STATISTICS.COLUMNS.REPLIED'),
        data: data.map(d => d.count),
        color: '#14b8a6',
      },
    ],
  };
});

const maxValue = computed(() => {
  const data = chartData.value;
  let max = 0;
  data.datasets.forEach(ds => {
    const dsMax = Math.max(...ds.data, 1);
    if (dsMax > max) max = dsMax;
  });
  return max;
});

const chartHeight = 220;
const containerRef = ref(null);
const containerWidth = ref(800);

const chartWidth = computed(() =>
  Math.max(containerWidth.value, chartData.value.labels.length * 24)
);

const xLabelStep = computed(() => {
  const count = chartData.value.labels.length;
  if (count <= 10) return 1;
  if (count <= 30) return Math.ceil(count / 10);
  return Math.ceil(count / 12);
});

function getYPosition(value) {
  const padding = 20;
  const height = chartHeight - padding * 2;
  return padding + height - (value / maxValue.value) * height;
}

function getXPosition(index) {
  const labels = chartData.value.labels;
  const padding = 36;
  const width = chartWidth.value - padding * 2;
  return padding + (index / Math.max(labels.length - 1, 1)) * width;
}

function formatDate(dateStr) {
  const date = new Date(dateStr);
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

let resizeObserver = null;

function updateWidth() {
  if (containerRef.value) {
    containerWidth.value = containerRef.value.clientWidth;
  }
}

onMounted(() => {
  updateWidth();
  if (typeof ResizeObserver !== 'undefined' && containerRef.value) {
    resizeObserver = new ResizeObserver(updateWidth);
    resizeObserver.observe(containerRef.value);
  } else {
    window.addEventListener('resize', updateWidth);
  }
});

onUnmounted(() => {
  if (resizeObserver) {
    resizeObserver.disconnect();
  } else {
    window.removeEventListener('resize', updateWidth);
  }
});
</script>

<template>
  <div class="rounded-xl border border-n-weak bg-n-solid-1 p-5 mb-6">
    <div
      class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-5"
    >
      <div class="flex items-center gap-2">
        <h3 class="text-sm font-semibold text-n-slate-12">
          {{ t('CAMPAIGNS.STATISTICS.CHART.TITLE') }}
        </h3>
        <div
          v-if="chartData.datasets.length"
          class="hidden md:flex items-center gap-3 pl-3 ml-1 border-l border-n-weak"
        >
          <div
            v-for="ds in chartData.datasets"
            :key="`legend-${ds.label}`"
            class="flex items-center gap-1.5"
          >
            <span
              class="size-2 rounded-full"
              :style="{ backgroundColor: ds.color }"
            />
            <span class="text-xs text-n-slate-10">{{ ds.label }}</span>
          </div>
        </div>
      </div>
      <div
        class="inline-flex items-center gap-0.5 rounded-lg bg-n-alpha-1 p-0.5 self-start"
      >
        <button
          v-for="metric in metrics"
          :key="metric.key"
          class="px-3 py-1 text-xs font-medium rounded-md transition-colors"
          :class="
            selectedMetric === metric.key
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-10 hover:text-n-slate-12'
          "
          @click="selectedMetric = metric.key"
        >
          {{ metric.label }}
        </button>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center h-56">
      <span class="i-lucide-loader-2 size-6 text-n-slate-9 animate-spin" />
    </div>

    <div
      v-else-if="!timeSeries.deliveries?.length"
      class="flex flex-col items-center justify-center h-56 gap-2"
    >
      <span class="i-lucide-bar-chart-3 size-8 text-n-slate-9" />
      <span class="text-sm text-n-slate-10">
        {{ t('CAMPAIGNS.STATISTICS.CHART.NO_DATA') }}
      </span>
    </div>

    <div v-else ref="containerRef" class="relative overflow-x-auto">
      <svg
        :width="chartWidth"
        :height="chartHeight + 40"
        class="block"
        :viewBox="`0 0 ${chartWidth} ${chartHeight + 40}`"
      >
        <defs>
          <linearGradient
            v-for="ds in chartData.datasets"
            :id="`gradient-${ds.label}`"
            :key="`gradient-${ds.label}`"
            x1="0%"
            y1="0%"
            x2="0%"
            y2="100%"
          >
            <stop offset="0%" :stop-color="ds.color" stop-opacity="0.25" />
            <stop offset="100%" :stop-color="ds.color" stop-opacity="0.02" />
          </linearGradient>
        </defs>

        <g class="grid-lines">
          <line
            v-for="i in 5"
            :key="`grid-${i}`"
            :x1="36"
            :x2="chartWidth - 10"
            :y1="20 + ((i - 1) / 4) * (chartHeight - 40)"
            :y2="20 + ((i - 1) / 4) * (chartHeight - 40)"
            stroke="currentColor"
            class="text-n-slate-5"
            stroke-dasharray="3 3"
          />
        </g>

        <g v-for="(ds, dsIndex) in chartData.datasets" :key="`area-${dsIndex}`">
          <path
            :d="`
              M ${getXPosition(0)} ${getYPosition(ds.data[0])}
              ${ds.data
                .slice(1)
                .map(
                  (val, idx) =>
                    `L ${getXPosition(idx + 1)} ${getYPosition(val)}`
                )
                .join(' ')}
              L ${getXPosition(ds.data.length - 1)} ${chartHeight - 20}
              L ${getXPosition(0)} ${chartHeight - 20}
              Z
            `"
            :fill="`url(#gradient-${ds.label})`"
          />
          <path
            :d="`
              M ${getXPosition(0)} ${getYPosition(ds.data[0])}
              ${ds.data
                .slice(1)
                .map(
                  (val, idx) =>
                    `L ${getXPosition(idx + 1)} ${getYPosition(val)}`
                )
                .join(' ')}
            `"
            fill="none"
            :stroke="ds.color"
            stroke-width="2"
            stroke-linejoin="round"
            stroke-linecap="round"
          />
          <circle
            v-for="(val, idx) in ds.data"
            :key="`point-${dsIndex}-${idx}`"
            :cx="getXPosition(idx)"
            :cy="getYPosition(val)"
            r="3"
            :fill="ds.color"
            class="opacity-0 hover:opacity-100 transition-opacity cursor-pointer"
          >
            <title>{{ `${chartData.labels[idx]}: ${val}` }}</title>
          </circle>
        </g>

        <g class="x-axis-labels">
          <text
            v-for="(label, idx) in chartData.labels"
            v-show="
              idx % xLabelStep === 0 || idx === chartData.labels.length - 1
            "
            :key="`label-${idx}`"
            :x="getXPosition(idx)"
            :y="chartHeight + 10"
            text-anchor="middle"
            class="text-[10px] fill-n-slate-9"
          >
            {{ formatDate(label) }}
          </text>
        </g>

        <g class="y-axis-labels">
          <text
            v-for="i in 5"
            :key="`y-label-${i}`"
            :x="30"
            :y="24 + ((i - 1) / 4) * (chartHeight - 40)"
            text-anchor="end"
            class="text-[10px] fill-n-slate-9"
          >
            {{ Math.round(maxValue - ((i - 1) / 4) * maxValue) }}
          </text>
        </g>
      </svg>
    </div>

    <div
      v-if="chartData.datasets.length"
      class="flex md:hidden items-center justify-center gap-4 mt-4 pt-4 border-t border-n-weak"
    >
      <div
        v-for="ds in chartData.datasets"
        :key="`legend-mobile-${ds.label}`"
        class="flex items-center gap-2"
      >
        <span
          class="size-2.5 rounded-full"
          :style="{ backgroundColor: ds.color }"
        />
        <span class="text-xs text-n-slate-10">{{ ds.label }}</span>
      </div>
    </div>
  </div>
</template>
