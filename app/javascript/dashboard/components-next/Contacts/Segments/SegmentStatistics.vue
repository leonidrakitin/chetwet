<script setup>
import { useI18n } from 'vue-i18n';

defineProps({
  statistics: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
</script>

<template>
  <section>
    <h2 class="mb-3 text-base font-medium text-n-slate-12">
      {{ t('SEGMENT_STATISTICS.TITLE') }}
    </h2>
    <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
      <div class="p-3 rounded-lg border border-n-weak bg-n-background">
        <div class="text-2xl font-semibold text-n-slate-12">
          {{ statistics.members_count ?? '—' }}
        </div>
        <div class="text-xs text-n-slate-11 mt-1">
          {{ t('SEGMENT_STATISTICS.MEMBERS') }}
        </div>
      </div>
      <div class="p-3 rounded-lg border border-n-weak bg-n-background">
        <div class="text-2xl font-semibold text-n-slate-12">
          {{ statistics.percent_of_total != null ? `${statistics.percent_of_total}%` : '—' }}
        </div>
        <div class="text-xs text-n-slate-11 mt-1">
          {{ t('SEGMENT_STATISTICS.PERCENT_OF_TOTAL') }}
        </div>
      </div>
      <div class="p-3 rounded-lg border border-n-weak bg-n-background">
        <div class="text-2xl font-semibold text-n-teal-11">
          +{{ statistics.entered_count ?? '—' }}
        </div>
        <div class="text-xs text-n-slate-11 mt-1">
          {{ t('SEGMENT_STATISTICS.ENTERED', { days: statistics.period_days || 30 }) }}
        </div>
      </div>
      <div class="p-3 rounded-lg border border-n-weak bg-n-background">
        <div class="text-2xl font-semibold text-n-ruby-11">
          -{{ statistics.exited_count ?? '—' }}
        </div>
        <div class="text-xs text-n-slate-11 mt-1">
          {{ t('SEGMENT_STATISTICS.EXITED', { days: statistics.period_days || 30 }) }}
        </div>
      </div>
    </div>
  </section>
</template>
