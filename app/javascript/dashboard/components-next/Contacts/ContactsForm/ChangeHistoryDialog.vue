<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useFunctionGetter } from 'dashboard/composables/store';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  segmentId: { type: [String, Number], default: null },
  segmentName: { type: String, default: '' },
});

const { t } = useI18n();
const store = useStore();
const dialogRef = ref(null);

const segmentIdRef = computed(() => props.segmentId);
const changeLogsPayload = useFunctionGetter(
  'contactSegments/getChangeLogsBySegmentId',
  segmentIdRef
);
const logs = computed(() => changeLogsPayload.value?.data ?? []);
const meta = computed(() => changeLogsPayload.value?.meta ?? {});
const currentPage = computed(() => meta.value.current_page ?? 1);
const totalPages = computed(() => meta.value.total_pages ?? 0);
const totalCount = computed(() => meta.value.total_count ?? 0);
const hasPages = computed(() => totalPages.value > 1);
const isLoading = ref(false);

const actionLabel = (action) => {
  const key =
    action === 'enter'
      ? 'CONTACT_FILTERS.SEGMENT_BUILDER.CHANGE_HISTORY.ENTER'
      : 'CONTACT_FILTERS.SEGMENT_BUILDER.CHANGE_HISTORY.EXIT';
  return t(key);
};

const sourceLabel = (triggerSource) => {
  const key = `CONTACT_FILTERS.SEGMENT_BUILDER.CHANGE_HISTORY.SOURCES.${triggerSource}`;
  const translated = t(key);
  return translated !== key ? translated : triggerSource;
};

const formatDetectedAt = (isoString) => {
  if (!isoString) return '—';
  try {
    const date = new Date(isoString);
    return new Intl.DateTimeFormat(undefined, {
      dateStyle: 'short',
      timeStyle: 'short',
    }).format(date);
  } catch {
    return isoString;
  }
};

const contactDisplay = (contact) => {
  if (!contact) return '—';
  const name = contact.name?.trim() || '—';
  const email = contact.email?.trim();
  return email ? `${name} (${email})` : name;
};

const loadPage = async (page) => {
  if (!props.segmentId) return;
  isLoading.value = true;
  try {
    await store.dispatch('contactSegments/getChangeLogs', {
      segmentId: props.segmentId,
      page,
    });
  } finally {
    isLoading.value = false;
  }
};

const open = () => {
  if (props.segmentId) loadPage(1);
  dialogRef.value?.open();
};

defineExpose({ dialogRef, open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    width="2xl"
    :title="t('CONTACT_FILTERS.SEGMENT_BUILDER.CHANGE_HISTORY.TITLE')"
    :show-confirm-button="false"
    :cancel-button-label="t('CONTACT_FILTERS.SEGMENT_BUILDER.CHANGE_HISTORY.CLOSE')"
    overflow-y-auto
  >
    <div class="flex flex-col gap-4 min-h-[12rem]">
      <p
        v-if="segmentName"
        class="text-sm text-n-slate-11"
      >
        {{ segmentName }}
      </p>
      <div
        v-if="isLoading && logs.length === 0"
        class="flex items-center justify-center py-8 text-n-slate-11"
      >
        {{ t('CONTACT_FILTERS.SEGMENT_BUILDER.CHANGE_HISTORY.LOADING') }}
      </div>
      <template v-else-if="logs.length === 0">
        <p class="py-6 text-center text-n-slate-11">
          {{ t('CONTACT_FILTERS.SEGMENT_BUILDER.CHANGE_HISTORY.NO_LOGS') }}
        </p>
      </template>
      <template v-else>
        <div class="overflow-x-auto border border-n-slate-6 rounded-lg">
          <table class="w-full text-sm text-left">
            <thead class="bg-n-alpha-2 text-n-slate-11">
              <tr>
                <th
                  class="px-4 py-3 font-medium"
                  scope="col"
                >
                  {{ t('CONTACT_FILTERS.SEGMENT_BUILDER.CHANGE_HISTORY.CONTACT') }}
                </th>
                <th
                  class="px-4 py-3 font-medium"
                  scope="col"
                >
                  {{ t('CONTACT_FILTERS.SEGMENT_BUILDER.CHANGE_HISTORY.ACTION') }}
                </th>
                <th
                  class="px-4 py-3 font-medium"
                  scope="col"
                >
                  {{ t('CONTACT_FILTERS.SEGMENT_BUILDER.CHANGE_HISTORY.TRIGGER_SOURCE') }}
                </th>
                <th
                  class="px-4 py-3 font-medium"
                  scope="col"
                >
                  {{ t('CONTACT_FILTERS.SEGMENT_BUILDER.CHANGE_HISTORY.REASON') }}
                </th>
                <th
                  class="px-4 py-3 font-medium"
                  scope="col"
                >
                  {{ t('CONTACT_FILTERS.SEGMENT_BUILDER.CHANGE_HISTORY.DETECTED_AT') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-slate-6">
              <tr
                v-for="log in logs"
                :key="log.id"
                class="bg-n-surface-1 text-n-slate-12"
              >
                <td class="px-4 py-3">
                  {{ contactDisplay(log.contact) }}
                </td>
                <td class="px-4 py-3">
                  {{ actionLabel(log.action) }}
                </td>
                <td class="px-4 py-3">
                  {{ sourceLabel(log.trigger_source) }}
                </td>
                <td class="px-4 py-3 max-w-[12rem] truncate" :title="log.reason">
                  {{ log.reason || '—' }}
                </td>
                <td class="px-4 py-3 whitespace-nowrap">
                  {{ formatDetectedAt(log.detected_at) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div
          v-if="hasPages"
          class="flex items-center justify-between gap-4"
        >
          <span class="text-sm text-n-slate-11">
            {{ t('CONTACT_FILTERS.SEGMENT_BUILDER.CHANGE_HISTORY.TOTAL_ENTRIES', { count: totalCount }) }}
          </span>
          <div class="flex items-center gap-2">
            <Button
              variant="ghost"
              color="slate"
              size="sm"
              icon="i-lucide-chevron-left"
              :disabled="currentPage <= 1 || isLoading"
              :aria-label="t('CONTACT_FILTERS.SEGMENT_BUILDER.CHANGE_HISTORY.CLOSE')"
              @click="loadPage(currentPage - 1)"
            />
            <span class="text-sm text-n-slate-11">
              {{ currentPage }} / {{ totalPages }}
            </span>
            <Button
              variant="ghost"
              color="slate"
              size="sm"
              icon="i-lucide-chevron-right"
              :disabled="currentPage >= totalPages || isLoading"
              :aria-label="t('CONTACT_FILTERS.SEGMENT_BUILDER.CHANGE_HISTORY.CLOSE')"
              @click="loadPage(currentPage + 1)"
            />
          </div>
        </div>
      </template>
    </div>
  </Dialog>
</template>
