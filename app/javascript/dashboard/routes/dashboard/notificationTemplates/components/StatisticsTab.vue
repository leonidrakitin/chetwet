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

    <!-- Table -->
    <div v-else class="rounded-xl border border-n-weak overflow-hidden">
      <table class="w-full text-sm">
        <thead>
          <tr class="bg-n-alpha-1 border-b border-n-weak">
            <th
              class="text-left px-4 py-3 font-semibold text-n-slate-11 w-full"
            >
              {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.TEMPLATE') }}
            </th>
            <th
              class="text-right px-4 py-3 font-semibold text-n-slate-11 whitespace-nowrap"
            >
              {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.SENT') }}
            </th>
            <th
              class="text-right px-4 py-3 font-semibold text-n-slate-11 whitespace-nowrap"
            >
              {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.FAILED') }}
            </th>
            <th
              class="text-right px-4 py-3 font-semibold text-n-slate-11 whitespace-nowrap"
            >
              {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.SKIPPED') }}
            </th>
            <th
              class="text-right px-4 py-3 font-semibold text-n-slate-11 whitespace-nowrap"
            >
              {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.REPLIED') }}
            </th>
            <th
              class="text-right px-4 py-3 font-semibold text-n-slate-11 whitespace-nowrap"
            >
              {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COLUMNS.REPLY_RATE') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in rows"
            :key="row.id"
            class="border-b border-n-weak last:border-0 hover:bg-n-alpha-1 transition-colors"
          >
            <td class="px-4 py-3 font-medium text-n-slate-12 truncate max-w-xs">
              {{ row.name }}
            </td>
            <td class="px-4 py-3 text-right text-n-slate-11 tabular-nums">
              {{ row.sent }}
            </td>
            <td class="px-4 py-3 text-right tabular-nums">
              <span :class="row.failed > 0 ? 'text-ruby-10' : 'text-n-slate-9'">
                {{ row.failed }}
              </span>
            </td>
            <td class="px-4 py-3 text-right text-n-slate-9 tabular-nums">
              {{ row.skipped }}
            </td>
            <td class="px-4 py-3 text-right text-n-slate-11 tabular-nums">
              {{ row.replied }}
            </td>
            <td class="px-4 py-3 text-right tabular-nums">
              <span
                class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
                :class="
                  row.replyRate >= 20
                    ? 'bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-300'
                    : 'bg-n-alpha-2 text-n-slate-10'
                "
              >
                {{ row.replyRate }}%
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
