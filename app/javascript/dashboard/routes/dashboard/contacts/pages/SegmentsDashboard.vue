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

const segments = useMapGetter('contactSegments/getSegments');
const segmentUIFlags = useMapGetter('contactSegments/getUIFlags');

const deleteDialogRef = ref(null);
const segmentToDelete = ref(null);

const isFetching = computed(() => segmentUIFlags.value.isFetching);

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
  } catch (error) {
    useAlert(t('SEGMENTS_DASHBOARD.DELETE_ERROR'));
  }
};

onMounted(() => {
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

      <!-- Segments List -->
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
          v-else-if="!segments.length"
          class="flex items-center justify-center py-10"
        >
          <span class="text-base text-n-slate-11">
            {{ t('SEGMENTS_DASHBOARD.EMPTY_STATE') }}
          </span>
        </div>
        <div v-else class="grid gap-3">
          <RouterLink
            v-for="segment in segments"
            :key="segment.id"
            :to="
              accountScopedRoute('contacts_segment_show', {
                segmentId: segment.id,
              })
            "
            class="flex items-center justify-between p-4 rounded-lg border border-n-weak bg-n-background hover:bg-n-alpha-1 transition-colors cursor-pointer no-underline"
          >
            <div class="flex flex-col gap-1 min-w-0">
              <span class="text-sm font-medium text-n-slate-12 truncate">
                {{ segment.name }}
              </span>
              <span
                v-if="segment.description"
                class="text-xs text-n-slate-11 truncate"
              >
                {{ segment.description }}
              </span>
            </div>
            <div class="flex items-center gap-2 flex-shrink-0">
              <span
                class="px-2 py-0.5 text-xs rounded-full"
                :class="
                  segment.active
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : 'bg-n-slate-3 text-n-slate-11'
                "
              >
                {{ segment.active ? t('SEGMENTS_DASHBOARD.ACTIVE') : t('SEGMENTS_DASHBOARD.INACTIVE') }}
              </span>
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
