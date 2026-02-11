<script setup>
import { onMounted, computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NotificationTypesManager from 'dashboard/components-next/Contacts/Segments/NotificationTypesManager.vue';

const store = useStore();
const { t } = useI18n();
const { accountScopedRoute } = useAccount();

const dashboardStats = useMapGetter('contactSegments/getDashboardStats');
const segmentUIFlags = useMapGetter('contactSegments/getUIFlags');

const deleteDialogRef = ref(null);
const segmentToDelete = ref(null);

const isFetching = computed(
  () => segmentUIFlags.value.isFetchingDashboard || segmentUIFlags.value.isFetching
);

const totalSegments = computed(() => dashboardStats.value.length);
const totalMembers = computed(() =>
  dashboardStats.value.reduce((sum, s) => sum + (s.members_count || 0), 0)
);
const totalEntered = computed(() =>
  dashboardStats.value.reduce((sum, s) => sum + (s.entered_count || 0), 0)
);
const totalExited = computed(() =>
  dashboardStats.value.reduce((sum, s) => sum + (s.exited_count || 0), 0)
);

const openDeleteDialog = segment => {
  segmentToDelete.value = segment;
  deleteDialogRef.value?.open?.();
};

const deleteSegment = async () => {
  if (!segmentToDelete.value) return;
  try {
    await store.dispatch('contactSegments/delete', segmentToDelete.value.id);
    useAlert(t('SEGMENTS_DASHBOARD.DELETE_SUCCESS'));
    deleteDialogRef.value?.close?.();
    segmentToDelete.value = null;
    store.dispatch('contactSegments/getDashboardStats');
  } catch (error) {
    useAlert(t('SEGMENTS_DASHBOARD.DELETE_ERROR'));
  }
};

onMounted(() => {
  store.dispatch('contactSegments/getDashboardStats');
  store.dispatch('contactSegments/get');
  store.dispatch('segmentNotificationTypes/get');
});
</script>

<template>
  <div
    class="flex flex-col flex-1 h-full m-0 overflow-auto bg-n-surface-1"
  >
    <div class="px-6 py-4">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ t('SEGMENTS_DASHBOARD.TITLE') }}
        </h1>
      </div>

      <!-- Summary Metrics -->
      <section class="grid grid-cols-4 gap-4 mb-8">
        <div class="p-4 rounded-lg border border-n-weak bg-n-background">
          <div class="text-xs text-n-slate-11 mb-1">
            {{ t('SEGMENTS_DASHBOARD.METRICS.TOTAL_SEGMENTS') }}
          </div>
          <div class="text-2xl font-semibold text-n-slate-12">
            {{ totalSegments }}
          </div>
        </div>
        <div class="p-4 rounded-lg border border-n-weak bg-n-background">
          <div class="text-xs text-n-slate-11 mb-1">
            {{ t('SEGMENTS_DASHBOARD.METRICS.TOTAL_MEMBERS') }}
          </div>
          <div class="text-2xl font-semibold text-n-slate-12">
            {{ totalMembers }}
          </div>
        </div>
        <div class="p-4 rounded-lg border border-n-weak bg-n-background">
          <div class="text-xs text-n-slate-11 mb-1">
            {{ t('SEGMENTS_DASHBOARD.METRICS.TOTAL_ENTERED') }}
          </div>
          <div class="text-2xl font-semibold text-n-teal-11">
            +{{ totalEntered }}
          </div>
        </div>
        <div class="p-4 rounded-lg border border-n-weak bg-n-background">
          <div class="text-xs text-n-slate-11 mb-1">
            {{ t('SEGMENTS_DASHBOARD.METRICS.TOTAL_EXITED') }}
          </div>
          <div class="text-2xl font-semibold text-n-ruby-11">
            -{{ totalExited }}
          </div>
        </div>
      </section>

      <!-- Segments Table -->
      <section class="mb-8">
        <h2 class="mb-4 text-base font-medium text-n-slate-12">
          {{ t('SEGMENTS_DASHBOARD.SEGMENTS_LIST') }}
        </h2>
        <div
          v-if="isFetching"
          class="flex items-center justify-center py-10 text-n-slate-11"
        >
          <Spinner />
        </div>
        <div
          v-else-if="!dashboardStats.length"
          class="flex items-center justify-center py-10"
        >
          <span class="text-base text-n-slate-11">
            {{ t('SEGMENTS_DASHBOARD.EMPTY_STATE') }}
          </span>
        </div>
        <div v-else>
          <!-- Table Header -->
          <div
            class="grid grid-cols-[1fr_100px_100px_100px_80px_40px] gap-3 px-4 py-2 text-xs font-medium text-n-slate-11 border-b border-n-weak"
          >
            <span>{{ t('SEGMENTS_DASHBOARD.TABLE.NAME') }}</span>
            <span class="text-right">{{ t('SEGMENTS_DASHBOARD.TABLE.MEMBERS') }}</span>
            <span class="text-right">{{ t('SEGMENTS_DASHBOARD.TABLE.ENTERED') }}</span>
            <span class="text-right">{{ t('SEGMENTS_DASHBOARD.TABLE.EXITED') }}</span>
            <span class="text-right">{{ t('SEGMENTS_DASHBOARD.TABLE.PERCENT') }}</span>
            <span />
          </div>
          <!-- Table Rows -->
          <RouterLink
            v-for="segment in dashboardStats"
            :key="segment.id"
            :to="
              accountScopedRoute('segment_show', {
                segmentId: segment.id,
              })
            "
            class="grid grid-cols-[1fr_100px_100px_100px_80px_40px] gap-3 items-center px-4 py-3 border-b border-n-weak hover:bg-n-alpha-1 transition-colors cursor-pointer no-underline"
          >
            <div class="flex items-center gap-2 min-w-0">
              <span class="text-sm font-medium text-n-slate-12 truncate">
                {{ segment.name }}
              </span>
              <span
                class="px-2 py-0.5 text-xs rounded-full flex-shrink-0"
                :class="
                  segment.active
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : 'bg-n-slate-3 text-n-slate-11'
                "
              >
                {{ segment.active ? t('SEGMENTS_DASHBOARD.ACTIVE') : t('SEGMENTS_DASHBOARD.INACTIVE') }}
              </span>
            </div>
            <span class="text-sm text-n-slate-12 text-right">
              {{ segment.members_count }}
            </span>
            <span class="text-sm text-n-teal-11 text-right">
              +{{ segment.entered_count }}
            </span>
            <span class="text-sm text-n-ruby-11 text-right">
              -{{ segment.exited_count }}
            </span>
            <span class="text-sm text-n-slate-11 text-right">
              {{ segment.percent_of_total }}%
            </span>
            <div class="flex justify-end">
              <Button
                icon="i-lucide-trash-2"
                color="slate"
                size="xs"
                @click.prevent="openDeleteDialog(segment)"
              />
            </div>
          </RouterLink>
        </div>
      </section>

      <!-- Notification Types -->
      <NotificationTypesManager />

      <!-- Delete Dialog -->
      <Dialog
        ref="deleteDialogRef"
        type="alert"
        :title="t('SEGMENTS_DASHBOARD.DELETE_DIALOG.TITLE')"
        :description="t('SEGMENTS_DASHBOARD.DELETE_DIALOG.DESCRIPTION')"
        :confirm-button-label="t('SEGMENTS_DASHBOARD.DELETE_DIALOG.CONFIRM')"
        @confirm="deleteSegment"
      />
    </div>
  </div>
</template>
