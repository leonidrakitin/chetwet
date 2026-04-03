<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';

const { t } = useI18n();
const store = useStore();

const uiFlags = computed(
  () => store.getters['notificationTemplates/getUIFlags']
);
const templates = computed(
  () => store.getters['notificationTemplates/getTemplates']
);
const statistics = computed(
  () => store.getters['notificationTemplates/getStatistics']
);

const rows = computed(() =>
  templates.value
    .map(tmpl => {
      const s = statistics.value[tmpl.id] || {};
      const sent = s.sent || 0;
      const failed = s.failed || 0;
      const skipped = s.skipped || 0;
      const replied = s.replied || 0;
      const total = sent + failed + skipped + replied;
      const replyRate = sent > 0 ? Math.round((replied / sent) * 100) : 0;
      return {
        id: tmpl.id,
        name: tmpl.name,
        sent,
        failed,
        skipped,
        replied,
        total,
        replyRate,
      };
    })
    .filter(r => r.total > 0)
);

const hasData = computed(() => rows.value.length > 0);
</script>

<template>
  <div class="max-w-6xl mx-auto py-6 px-4 md:px-0">
    <!-- Loading -->
    <div
      v-if="uiFlags.isFetchingStatistics"
      class="flex items-center justify-center py-16 gap-3 text-n-slate-9"
    >
      <span class="i-lucide-loader-2 size-5 animate-spin" />
      <span class="text-sm">{{
        t('NOTIFICATION_TEMPLATES.STATISTICS.LOADING')
      }}</span>
    </div>

    <!-- Empty -->
    <div
      v-else-if="!hasData"
      class="flex flex-col items-center justify-center py-16 gap-4"
    >
      <div
        class="flex items-center justify-center size-16 rounded-2xl bg-n-alpha-1"
      >
        <span class="i-lucide-bar-chart-3 size-8 text-n-slate-9" />
      </div>
      <p class="text-sm text-n-slate-10 text-center max-w-xs">
        {{ t('NOTIFICATION_TEMPLATES.STATISTICS.EMPTY') }}
      </p>
    </div>

    <!-- List View instead of Table -->
    <div v-else class="flex flex-col gap-3">
      <!-- Headers -->
      <div
        class="hidden md:flex items-center px-6 py-2 bg-n-alpha-1 rounded-xl text-xs font-semibold text-n-slate-10 uppercase tracking-wider"
      >
        <div class="flex-1">
          {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.TEMPLATE') }}
        </div>
        <div class="w-24 text-right">
          {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.SENT') }}
        </div>
        <div class="w-24 text-right">
          {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.FAILED') }}
        </div>
        <div class="w-24 text-right hidden lg:block">
          {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.SKIPPED') }}
        </div>
        <div class="w-24 text-right hidden lg:block">
          {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.REPLIED') }}
        </div>
        <div class="w-32 text-right">
          {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.REPLY_RATE') }}
        </div>
      </div>

      <!-- Rows -->
      <div
        v-for="row in rows"
        :key="row.id"
        class="flex flex-col md:flex-row md:items-center p-4 md:px-6 md:py-4 rounded-xl border border-n-weak bg-n-solid-1 hover:border-n-strong hover:shadow-md transition-all gap-4"
      >
        <div class="flex-1 min-w-0">
          <h3 class="text-sm font-semibold text-n-slate-12 truncate">
            {{ row.name }}
          </h3>
        </div>

        <div
          class="flex flex-wrap md:flex-nowrap items-center gap-4 md:gap-0 mt-2 md:mt-0"
        >
          <div class="w-24 flex flex-col md:text-right">
            <span class="md:hidden text-[10px] uppercase text-n-slate-9 mb-0.5">
              {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.SENT') }}
            </span>
            <span class="text-sm font-medium text-n-slate-11 tabular-nums">
              {{ row.sent }}
            </span>
          </div>

          <div class="w-24 flex flex-col md:text-right">
            <span class="md:hidden text-[10px] uppercase text-n-slate-9 mb-0.5">
              {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.FAILED') }}
            </span>
            <span
              class="text-sm font-medium tabular-nums"
              :class="row.failed > 0 ? 'text-ruby-10' : 'text-n-slate-9'"
            >
              {{ row.failed }}
            </span>
          </div>

          <div class="w-24 flex flex-col md:text-right hidden lg:flex">
            <span class="text-sm text-n-slate-9 tabular-nums">{{
              row.skipped
            }}</span>
          </div>

          <div class="w-24 flex flex-col md:text-right hidden lg:flex">
            <span class="text-sm text-n-slate-11 tabular-nums">{{
              row.replied
            }}</span>
          </div>

          <div class="w-32 flex flex-col md:text-right lg:items-end">
            <span class="md:hidden text-[10px] uppercase text-n-slate-9 mb-0.5">
              {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.REPLY_RATE') }}
            </span>
            <span
              class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium w-fit"
              :class="
                row.replyRate >= 20
                  ? 'bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-300'
                  : 'bg-n-alpha-2 text-n-slate-10'
              "
            >
              {{
                t('NOTIFICATION_TEMPLATES.STATISTICS.REPLY_RATE_PERCENT', {
                  value: row.replyRate,
                })
              }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
