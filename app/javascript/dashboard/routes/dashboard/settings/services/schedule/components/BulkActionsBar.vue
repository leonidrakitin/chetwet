<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  selectedBookings: { type: Array, default: () => [] },
  providers: { type: Array, default: () => [] },
});

const emit = defineEmits(['clearSelection', 'completed']);

const { t } = useI18n();
const store = useStore();

const showConfirmDialog = ref(false);
const showCancelDialog = ref(false);
const showCompleteDialog = ref(false);
const showReassignDialog = ref(false);
const selectedProviderId = ref(null);
const cancelReason = ref('');
const isProcessing = ref(false);

const selectedCount = computed(() => props.selectedBookings.length);

const hasSelection = computed(() => selectedCount.value > 0);

const openConfirmDialog = () => {
  showConfirmDialog.value = true;
};

const openCancelDialog = () => {
  showCancelDialog.value = true;
};

const openReassignDialog = () => {
  showReassignDialog.value = true;
};

const handleConfirm = async () => {
  isProcessing.value = true;
  try {
    await Promise.all(
      props.selectedBookings.map(booking =>
        store.dispatch('services/updateBooking', {
          id: booking.id,
          booking: { status: 'confirmed' },
        })
      )
    );
    useAlert(t('SCHEDULE.BULK.SUCCESS'));
    emit('completed');
    emit('clearSelection');
  } catch (error) {
    useAlert(error.message || t('SCHEDULE.BULK.ERROR'));
  } finally {
    isProcessing.value = false;
    showConfirmDialog.value = false;
  }
};

const handleCancel = async () => {
  isProcessing.value = true;
  try {
    await Promise.all(
      props.selectedBookings.map(booking =>
        store.dispatch('services/cancelBooking', {
          id: booking.id,
          reason: cancelReason.value,
        })
      )
    );
    useAlert(t('SCHEDULE.BULK.SUCCESS'));
    emit('completed');
    emit('clearSelection');
  } catch (error) {
    useAlert(error.message || t('SCHEDULE.BULK.ERROR'));
  } finally {
    isProcessing.value = false;
    showCancelDialog.value = false;
    cancelReason.value = '';
  }
};

const handleComplete = async () => {
  isProcessing.value = true;
  try {
    await Promise.all(
      props.selectedBookings.map(booking =>
        store.dispatch('services/updateBooking', {
          id: booking.id,
          booking: { status: 'completed' },
        })
      )
    );
    useAlert(t('SCHEDULE.BULK.SUCCESS'));
    emit('completed');
    emit('clearSelection');
  } catch (error) {
    useAlert(error.message || t('SCHEDULE.BULK.ERROR'));
  } finally {
    isProcessing.value = false;
    showCompleteDialog.value = false;
  }
};

const handleReassign = async () => {
  if (!selectedProviderId.value) return;

  isProcessing.value = true;
  try {
    await Promise.all(
      props.selectedBookings.map(booking =>
        store.dispatch('services/updateBooking', {
          id: booking.id,
          booking: { service_provider_id: selectedProviderId.value },
        })
      )
    );
    useAlert(t('SCHEDULE.BULK.SUCCESS'));
    emit('completed');
    emit('clearSelection');
  } catch (error) {
    useAlert(error.message || t('SCHEDULE.BULK.ERROR'));
  } finally {
    isProcessing.value = false;
    showReassignDialog.value = false;
    selectedProviderId.value = null;
  }
};
</script>

<template>
  <Transition
    enter-active-class="transition-all duration-200"
    leave-active-class="transition-all duration-200"
    enter-from-class="translate-y-full opacity-0"
    leave-to-class="translate-y-full opacity-0"
  >
    <div
      v-if="hasSelection"
      class="fixed bottom-4 left-1/2 -translate-x-1/2 z-50 flex items-center gap-4 px-4 py-3 bg-n-solid-1 border border-n-weak rounded-lg shadow-lg"
    >
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('SCHEDULE.BULK.SELECTED', { count: selectedCount }) }}
      </span>

      <div class="flex items-center gap-2">
        <Button
          :label="t('SCHEDULE.BULK.CONFIRM')"
          faded
          sm
          @click="openConfirmDialog"
        />
        <Button
          :label="t('SCHEDULE.BULK.COMPLETE')"
          faded
          sm
          @click="showCompleteDialog = true"
        />
        <Button
          :label="t('SCHEDULE.BULK.CANCEL')"
          faded
          ruby
          sm
          @click="openCancelDialog"
        />
        <Button
          :label="t('SCHEDULE.BULK.REASSIGN')"
          faded
          sm
          @click="openReassignDialog"
        />
        <Button icon="i-lucide-x" slate sm @click="emit('clearSelection')" />
      </div>
    </div>
  </Transition>

  <Dialog
    :show="showConfirmDialog"
    :title="t('SCHEDULE.BULK.CONFIRM_SELECTED')"
    @close="showConfirmDialog = false"
  >
    <template #body>
      <p class="text-sm text-n-slate-11">
        {{ t('SCHEDULE.BULK.CONFIRM_PROMPT', { count: selectedCount }) }}
      </p>
    </template>
    <template #footer>
      <div class="flex justify-end gap-2">
        <Button
          :label="t('SCHEDULE.MODAL.CANCEL')"
          faded
          @click="showConfirmDialog = false"
        />
        <Button
          :label="t('SCHEDULE.BULK.CONFIRM')"
          :is-loading="isProcessing"
          @click="handleConfirm"
        />
      </div>
    </template>
  </Dialog>

  <Dialog
    :show="showCancelDialog"
    :title="t('SCHEDULE.BULK.CANCEL_SELECTED')"
    @close="showCancelDialog = false"
  >
    <template #body>
      <p class="text-sm text-n-slate-11 mb-3">
        {{ t('SCHEDULE.BULK.CANCEL_PROMPT', { count: selectedCount }) }}
      </p>
      <label class="block text-sm font-medium text-n-slate-12 mb-1">
        {{ t('SCHEDULE.MODAL.CANCEL_REASON') }}
      </label>
      <textarea
        v-model="cancelReason"
        rows="2"
        class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand resize-none"
      />
    </template>
    <template #footer>
      <div class="flex justify-end gap-2">
        <Button
          :label="t('SCHEDULE.MODAL.CANCEL')"
          faded
          slate
          @click="showCancelDialog = false"
        />
        <Button
          :label="t('SCHEDULE.BULK.CANCEL')"
          ruby
          :is-loading="isProcessing"
          @click="handleCancel"
        />
      </div>
    </template>
  </Dialog>

  <Dialog
    :show="showCompleteDialog"
    :title="t('SCHEDULE.BULK.COMPLETE_SELECTED')"
    @close="showCompleteDialog = false"
  >
    <template #body>
      <p class="text-sm text-n-slate-11">
        {{ t('SCHEDULE.BULK.COMPLETE_PROMPT', { count: selectedCount }) }}
      </p>
    </template>
    <template #footer>
      <div class="flex justify-end gap-2">
        <Button
          :label="t('SCHEDULE.MODAL.CANCEL')"
          faded
          slate
          @click="showCompleteDialog = false"
        />
        <Button
          :label="t('SCHEDULE.BULK.COMPLETE')"
          :is-loading="isProcessing"
          @click="handleComplete"
        />
      </div>
    </template>
  </Dialog>

  <Dialog
    :show="showReassignDialog"
    :title="t('SCHEDULE.BULK.REASSIGN_TO')"
    @close="showReassignDialog = false"
  >
    <template #body>
      <select
        v-model="selectedProviderId"
        class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
      >
        <option :value="null" disabled>
          {{ t('SCHEDULE.MODAL.PROVIDER') }}
        </option>
        <option
          v-for="provider in providers"
          :key="provider.id"
          :value="provider.id"
        >
          {{ provider.name }}
        </option>
      </select>
    </template>
    <template #footer>
      <div class="flex justify-end gap-2">
        <Button
          :label="t('SCHEDULE.MODAL.CANCEL')"
          faded
          @click="showReassignDialog = false"
        />
        <Button
          :label="t('SCHEDULE.BULK.REASSIGN')"
          :is-loading="isProcessing"
          :disabled="!selectedProviderId"
          @click="handleReassign"
        />
      </div>
    </template>
  </Dialog>
</template>
