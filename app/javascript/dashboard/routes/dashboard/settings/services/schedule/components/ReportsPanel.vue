<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { format, subDays } from 'date-fns';
import ServicesReportsAPI from 'dashboard/api/servicesReports';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();

const isLoading = ref(false);
const reports = ref(null);

const dateRange = ref({
  start: format(subDays(new Date(), 30), 'yyyy-MM-dd'),
  end: format(new Date(), 'yyyy-MM-dd'),
});

const fetchReports = async () => {
  isLoading.value = true;
  try {
    const response = await ServicesReportsAPI.getReports({
      start_date: dateRange.value.start,
      end_date: dateRange.value.end,
    });
    reports.value = response.data;
  } catch (error) {
    reports.value = null;
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  fetchReports();
});

const bookingStats = computed(() => reports.value?.booking_stats || {});
const providerUtilization = computed(
  () => reports.value?.provider_utilization || []
);
const peakHours = computed(() => reports.value?.peak_hours || []);
const servicePopularity = computed(
  () => reports.value?.service_popularity || []
);

const maxPeakHour = computed(() => {
  return Math.max(...peakHours.value.map(h => h.count), 1);
});

const getUtilizationColor = rate => {
  if (rate >= 80) return 'bg-green-500';
  if (rate >= 50) return 'bg-yellow-500';
  return 'bg-red-500';
};

const formatDuration = minutes => {
  if (minutes < 60) return `${minutes} ${t('SCHEDULE.SETTINGS.MINUTES')}`;
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return mins > 0 ? `${hours}h ${mins}m` : `${hours}h`;
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="flex items-center justify-between">
      <h2 class="text-lg font-semibold text-n-text-display">
        {{ t('SCHEDULE.REPORTS.HEADER') }}
      </h2>
      <div class="flex items-center gap-2">
        <input
          v-model="dateRange.start"
          type="date"
          class="px-3 py-1.5 text-sm border border-n-border-glass-soft rounded-md bg-n-glass-soft text-n-text-display"
        />
        <span class="text-n-text-body/60">—</span>
        <input
          v-model="dateRange.end"
          type="date"
          class="px-3 py-1.5 text-sm border border-n-border-glass-soft rounded-md bg-n-glass-soft text-n-text-display"
        />
        <Button :label="t('SCHEDULE.REPORTS.APPLY')" sm @click="fetchReports" />
      </div>
    </div>

    <Spinner v-if="isLoading" class="m-auto" />

    <div v-else class="grid grid-cols-4 gap-4">
      <div
        class="p-4 bg-n-glass-soft rounded-lg border border-n-border-glass-soft"
      >
        <div class="text-sm text-n-text-body/60">
          {{ t('SCHEDULE.REPORTS.TOTAL_BOOKINGS') }}
        </div>
        <div class="text-2xl font-bold text-n-text-display">
          {{ bookingStats.total || 0 }}
        </div>
      </div>
      <div
        class="p-4 bg-n-glass-soft rounded-lg border border-n-border-glass-soft"
      >
        <div class="text-sm text-n-text-body/60">
          {{ t('SCHEDULE.REPORTS.CONFIRMED') }}
        </div>
        <div class="text-2xl font-bold text-blue-600">
          {{ bookingStats.confirmed || 0 }}
        </div>
      </div>
      <div
        class="p-4 bg-n-glass-soft rounded-lg border border-n-border-glass-soft"
      >
        <div class="text-sm text-n-text-body/60">
          {{ t('SCHEDULE.REPORTS.COMPLETED') }}
        </div>
        <div class="text-2xl font-bold text-green-600">
          {{ bookingStats.completed || 0 }}
        </div>
      </div>
      <div
        class="p-4 bg-n-glass-soft rounded-lg border border-n-border-glass-soft"
      >
        <div class="text-sm text-n-text-body/60">
          {{ t('SCHEDULE.REPORTS.CANCELLED') }}
        </div>
        <div class="text-2xl font-bold text-red-600">
          {{ bookingStats.cancelled || 0 }}
        </div>
      </div>
    </div>

    <div class="grid grid-cols-2 gap-6">
      <div
        class="p-4 bg-n-glass-soft rounded-lg border border-n-border-glass-soft"
      >
        <h3 class="text-sm font-semibold text-n-text-display mb-4">
          {{ t('SCHEDULE.REPORTS.PROVIDER_UTILIZATION') }}
        </h3>
        <div class="space-y-3">
          <div
            v-for="provider in providerUtilization"
            :key="provider.id"
            class="flex items-center gap-3"
          >
            <div class="w-24 text-sm text-n-text-display truncate">
              {{ provider.name }}
            </div>
            <div class="flex-1 h-4 bg-n-solid-3 rounded overflow-hidden">
              <div
                class="h-full transition-all"
                :class="getUtilizationColor(provider.utilization_rate)"
                :style="{
                  width: `${Math.min(provider.utilization_rate, 100)}%`,
                }"
              />
            </div>
            <div class="w-16 text-sm text-right text-n-text-body">
              {{ provider.utilization_rate }}%
            </div>
          </div>
        </div>
      </div>

      <div
        class="p-4 bg-n-glass-soft rounded-lg border border-n-border-glass-soft"
      >
        <h3 class="text-sm font-semibold text-n-text-display mb-4">
          {{ t('SCHEDULE.REPORTS.PEAK_HOURS') }}
        </h3>
        <div class="flex items-end gap-1 h-32">
          <div
            v-for="hour in peakHours"
            :key="hour.hour"
            class="flex-1 flex flex-col items-center"
          >
            <div
              class="w-full bg-n-brand rounded-t transition-all"
              :style="{ height: `${(hour.count / maxPeakHour) * 100}%` }"
              :title="`${hour.label}: ${hour.count} bookings`"
            />
            <div class="text-xs text-n-text-body/60 mt-1">{{ hour.hour }}</div>
          </div>
        </div>
      </div>
    </div>

    <div
      class="p-4 bg-n-glass-soft rounded-lg border border-n-border-glass-soft"
    >
      <h3 class="text-sm font-semibold text-n-text-display mb-4">
        {{ t('SCHEDULE.REPORTS.SERVICE_POPULARITY') }}
      </h3>
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead>
            <tr class="border-b border-n-border-glass-soft">
              <th class="text-left text-sm text-n-text-body/60 py-2">
                {{ t('SCHEDULE.REPORTS.SERVICE') }}
              </th>
              <th class="text-right text-sm text-n-text-body/60 py-2">
                {{ t('SCHEDULE.REPORTS.DURATION') }}
              </th>
              <th class="text-right text-sm text-n-text-body/60 py-2">
                {{ t('SCHEDULE.REPORTS.BOOKINGS') }}
              </th>
              <th class="text-right text-sm text-n-text-body/60 py-2">
                {{ t('SCHEDULE.REPORTS.REVENUE') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="service in servicePopularity"
              :key="service.id"
              class="border-b border-n-border-glass-soft last:border-0"
            >
              <td class="text-sm text-n-text-display py-2">
                {{ service.name }}
              </td>
              <td class="text-sm text-right text-n-text-body py-2">
                {{ formatDuration(service.duration_minutes) }}
              </td>
              <td class="text-sm text-right text-n-text-body py-2">
                {{ service.booking_count }}
              </td>
              <td
                class="text-sm text-right text-n-text-display py-2 font-medium"
              >
                {{ service.revenue ? `$${service.revenue.toFixed(2)}` : '—' }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
