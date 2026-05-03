<script setup>
import { ref, computed, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { format } from 'date-fns';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ContactSearchCombobox from './ContactSearchCombobox.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  booking: { type: Object, default: null },
  initialProviderId: { type: [Number, String], default: null },
  initialTime: { type: Date, default: null },
  initialDurationMinutes: { type: Number, default: null },
  providers: { type: Array, default: () => [] },
  services: { type: Array, default: () => [] },
});

const emit = defineEmits(['close', 'saved']);

const { t } = useI18n();
const store = useStore();

const isEditing = computed(() => !!props.booking);
const STATUS_OPTIONS = [
  'pending',
  'confirmed',
  'arrived',
  'no_show',
  'completed',
  'cancelled',
];

/** Segmented control: idle + selected styles (aligned with calendar card colors). */
const STATUS_SEGMENT_IDLE =
  'border border-n-border-glass-soft bg-n-glass-strong text-n-text-body shadow-sm hover:bg-n-solid-3 hover:border-n-slate-6';

const STATUS_SEGMENT_SELECTED = {
  pending:
    'border border-n-amber-9/60 bg-n-amber-3 text-n-amber-12 shadow-md ring-2 ring-n-amber-9/25',
  confirmed:
    'border border-n-blue-9/60 bg-n-blue-3 text-n-blue-12 shadow-md ring-2 ring-n-blue-9/25',
  arrived:
    'border border-n-teal-9/60 bg-n-teal-3 text-n-teal-12 shadow-md ring-2 ring-n-teal-9/25',
  no_show:
    'border border-n-ruby-9/60 bg-n-ruby-3 text-n-ruby-12 shadow-md ring-2 ring-n-ruby-9/25',
  completed:
    'border border-n-violet-9/60 bg-n-violet-3 text-n-violet-12 shadow-md ring-2 ring-n-violet-9/25',
  cancelled:
    'border border-n-ruby-10/80 bg-n-ruby-5 text-n-ruby-12 shadow-md ring-2 ring-n-ruby-10/35',
};

const STATUS_SEGMENT_ICON = {
  pending: 'i-lucide-clock-3',
  confirmed: 'i-lucide-shield-check',
  arrived: 'i-lucide-log-in',
  no_show: 'i-lucide-user-x',
  completed: 'i-lucide-badge-check',
  cancelled: 'i-lucide-circle-x',
};

const dialogRef = ref(null);
const deleteDialogRef = ref(null);
const form = ref({
  service_provider_id: null,
  scheduled_at: '',
  contact_id: null,
  customer_notes: '',
  internal_notes: '',
  service_ids: [],
  status: 'pending',
  cancellation_reason: '',
});
const initialStatus = ref('pending');

const statusSegmentClass = status => {
  if (form.value.status !== status) return STATUS_SEGMENT_IDLE;
  return STATUS_SEGMENT_SELECTED[status] ?? STATUS_SEGMENT_SELECTED.pending;
};
const selectedContact = ref(null);
const selectedServices = ref([]);
const isSubmitting = ref(false);
const isDeleting = ref(false);
const hasRequiredFields = computed(() => {
  return (
    !!form.value.service_provider_id &&
    !!form.value.scheduled_at &&
    !!form.value.contact_id &&
    selectedServices.value.length > 0
  );
});

const initForm = () => {
  if (props.booking) {
    form.value = {
      service_provider_id: props.booking.service_provider?.id,
      scheduled_at: format(
        new Date(props.booking.scheduled_at),
        "yyyy-MM-dd'T'HH:mm"
      ),
      contact_id: props.booking.contact?.id,
      customer_notes: props.booking.customer_notes || '',
      internal_notes: props.booking.internal_notes || '',
      service_ids: props.booking.services?.map(s => s.id) || [],
      status: props.booking.status || 'pending',
      cancellation_reason: props.booking.cancellation_reason || '',
    };
    initialStatus.value = props.booking.status || 'pending';
    selectedContact.value = props.booking.contact;
    selectedServices.value = props.booking.services || [];
  } else {
    form.value = {
      service_provider_id: props.initialProviderId,
      scheduled_at: props.initialTime
        ? format(props.initialTime, "yyyy-MM-dd'T'HH:mm")
        : '',
      contact_id: null,
      customer_notes: '',
      internal_notes: '',
      service_ids: [],
      status: 'pending',
      cancellation_reason: '',
    };
    initialStatus.value = 'pending';
    selectedContact.value = null;
    selectedServices.value = [];
  }
};

const openDeleteConfirm = () => deleteDialogRef.value?.open();
const closeDeleteConfirm = () => deleteDialogRef.value?.close();

watch(
  () => props.show,
  async isVisible => {
    if (!isVisible) return;
    initForm();
    await nextTick();
    dialogRef.value?.open();
  },
  { immediate: true }
);

const title = computed(() =>
  isEditing.value
    ? t('SCHEDULE.MODAL.EDIT_TITLE')
    : t('SCHEDULE.MODAL.CREATE_TITLE')
);

const handleStatusChange = async () => {
  if (!isEditing.value) return;
  const newStatus = form.value.status;
  if (newStatus === initialStatus.value) return;
  if (newStatus === 'cancelled') {
    await store.dispatch('services/cancelBooking', {
      id: props.booking.id,
      reason: form.value.cancellation_reason,
    });
  } else if (newStatus === 'confirmed') {
    await store.dispatch('services/confirmBooking', { id: props.booking.id });
  } else {
    await store.dispatch('services/updateBooking', {
      id: props.booking.id,
      booking: { status: newStatus },
    });
  }
  initialStatus.value = newStatus;
};

const handleSubmit = async () => {
  if (!hasRequiredFields.value) {
    return;
  }
  isSubmitting.value = true;
  try {
    const bookingData = {
      service_provider_id: form.value.service_provider_id,
      scheduled_at: form.value.scheduled_at,
      contact_id: form.value.contact_id,
      customer_notes: form.value.customer_notes,
      internal_notes: form.value.internal_notes,
      service_booking_items_attributes: selectedServices.value.map(
        (service, index) => ({
          service_id: service.id || service,
          position: index,
        })
      ),
    };

    let result;
    if (isEditing.value) {
      result = await store.dispatch('services/updateBooking', {
        id: props.booking.id,
        booking: bookingData,
      });
      await handleStatusChange();
    } else {
      result = await store.dispatch('services/createBooking', {
        booking: bookingData,
      });
      if (
        result?.id &&
        props.initialDurationMinutes &&
        props.initialDurationMinutes !== result.total_duration_minutes
      ) {
        result = await store.dispatch('services/updateBooking', {
          id: result.id,
          booking: { total_duration_minutes: props.initialDurationMinutes },
        });
      }
    }

    useAlert(
      t(`SCHEDULE.MODAL.${isEditing.value ? 'UPDATE' : 'CREATE'}_SUCCESS`)
    );
    emit('saved', result);
    emit('close');
  } catch (error) {
    useAlert(error.message || t('SCHEDULE.MODAL.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};

const handleDelete = async () => {
  if (!isEditing.value) return;
  isDeleting.value = true;
  try {
    await store.dispatch('services/deleteBooking', { id: props.booking.id });
    useAlert(t('SCHEDULE.MODAL.DELETE_SUCCESS'));
    emit('saved');
    emit('close');
  } catch (error) {
    useAlert(error.message || t('SCHEDULE.MODAL.ERROR'));
  } finally {
    isDeleting.value = false;
    closeDeleteConfirm();
  }
};

const handleCancel = () => emit('close');

watch(selectedContact, contact => {
  form.value.contact_id = contact?.id ?? null;
});

const toggleService = service => {
  const index = selectedServices.value.findIndex(s => s.id === service.id);
  if (index === -1) selectedServices.value.push(service);
  else selectedServices.value.splice(index, 1);
};

const isServiceSelected = serviceId =>
  selectedServices.value.some(s => s.id === serviceId);
</script>

<template>
  <Dialog
    v-if="show"
    ref="dialogRef"
    :title="title"
    width="2xl"
    max-height="min(90dvh, 100vh - 2rem)"
    @close="handleCancel"
  >
    <div class="flex flex-col gap-4">
      <div>
        <label class="block text-sm font-medium text-n-text-display mb-1">{{
          t('SCHEDULE.MODAL.PROVIDER')
        }}</label>
        <select
          v-model="form.service_provider_id"
          class="w-full px-3 py-2 border border-n-border-glass-soft rounded-md bg-n-glass-soft text-n-text-display focus:outline-none focus:ring-2 focus:ring-n-brand"
        >
          <option
            v-for="provider in providers"
            :key="provider.id"
            :value="provider.id"
          >
            {{ provider.name }}
          </option>
        </select>
      </div>

      <div>
        <label class="block text-sm font-medium text-n-text-display mb-1">{{
          t('SCHEDULE.MODAL.DATE_TIME')
        }}</label>
        <input
          v-model="form.scheduled_at"
          type="datetime-local"
          class="w-full px-3 py-2 border border-n-border-glass-soft rounded-md bg-n-glass-soft text-n-text-display focus:outline-none focus:ring-2 focus:ring-n-brand"
        />
        <p
          v-if="!isEditing && initialDurationMinutes"
          class="mt-1 text-xs text-n-text-body/60"
        >
          {{ t('SCHEDULE.MODAL.PLANNED_DURATION') }}: {{ initialDurationMinutes
          }}{{ t('SCHEDULE.MODAL.MIN') }}
        </p>
      </div>

      <div>
        <label class="block text-sm font-medium text-n-text-display mb-1">{{
          t('SCHEDULE.MODAL.CONTACT')
        }}</label>
        <ContactSearchCombobox
          v-model="selectedContact"
          :placeholder="t('SCHEDULE.MODAL.SEARCH_CONTACT')"
          :has-error="isSubmitting && !form.contact_id"
        />
      </div>

      <div>
        <label class="block text-sm font-medium text-n-text-display mb-1">{{
          t('SCHEDULE.MODAL.SERVICES')
        }}</label>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="service in services"
            :key="service.id"
            class="px-3 py-1.5 text-sm rounded-md border transition-colors"
            :class="
              isServiceSelected(service.id)
                ? 'bg-n-brand border-n-brand text-white'
                : 'bg-n-glass-soft border-n-border-glass-soft text-n-text-display hover:border-n-brand'
            "
            @click="toggleService(service)"
          >
            {{ service.name }}
            <span class="text-xs opacity-70">
              {{ service.duration_minutes }}{{ t('SCHEDULE.MODAL.MIN') }}
            </span>
          </button>
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-n-text-display mb-1">{{
          t('SCHEDULE.MODAL.CUSTOMER_NOTES')
        }}</label>
        <textarea
          v-model="form.customer_notes"
          rows="2"
          class="w-full px-3 py-2 border border-n-border-glass-soft rounded-md bg-n-glass-soft text-n-text-display focus:outline-none focus:ring-2 focus:ring-n-brand resize-none"
        />
      </div>

      <div>
        <label class="block text-sm font-medium text-n-text-display mb-1">{{
          t('SCHEDULE.MODAL.INTERNAL_NOTES')
        }}</label>
        <textarea
          v-model="form.internal_notes"
          rows="2"
          class="w-full px-3 py-2 border border-n-border-glass-soft rounded-md bg-n-glass-soft text-n-text-display focus:outline-none focus:ring-2 focus:ring-n-brand resize-none"
        />
      </div>

      <div v-if="isEditing">
        <label
          id="booking-status-label"
          class="block text-sm font-medium text-n-text-display mb-2"
        >
          {{ t('SCHEDULE.MODAL.STATUS') }}
        </label>
        <div
          class="rounded-2xl border border-n-border-glass-soft/80 bg-n-glass-strong/80 p-1.5 shadow-[inset_0_1px_0_0_rgba(255,255,255,0.04)]"
        >
          <div
            role="radiogroup"
            aria-labelledby="booking-status-label"
            class="grid grid-cols-2 sm:grid-cols-3 gap-1.5"
          >
            <button
              v-for="status in STATUS_OPTIONS"
              :key="status"
              type="button"
              role="radio"
              :aria-checked="form.status === status"
              class="flex items-center gap-2 rounded-xl px-3 py-2.5 text-left text-sm font-medium transition-all duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-n-brand focus-visible:ring-offset-2 focus-visible:ring-offset-n-alpha-3"
              :class="statusSegmentClass(status)"
              @click="form.status = status"
            >
              <span
                class="size-5 shrink-0 opacity-90"
                :class="STATUS_SEGMENT_ICON[status]"
                aria-hidden="true"
              />
              <span class="min-w-0 leading-snug">{{
                t(`SCHEDULE.STATUS.${status.toUpperCase()}`)
              }}</span>
            </button>
          </div>
        </div>
      </div>

      <div v-if="isEditing && form.status === 'cancelled'">
        <label class="block text-sm font-medium text-n-text-display mb-1">{{
          t('SCHEDULE.MODAL.CANCEL_REASON')
        }}</label>
        <textarea
          v-model="form.cancellation_reason"
          rows="2"
          class="w-full px-3 py-2 border border-n-border-glass-soft rounded-md bg-n-glass-soft text-n-text-display focus:outline-none focus:ring-2 focus:ring-n-brand resize-none"
        />
      </div>
    </div>

    <template #footer>
      <div class="flex justify-between gap-2">
        <Button
          v-if="isEditing"
          :label="t('SCHEDULE.MODAL.DELETE')"
          icon="i-lucide-trash-2"
          ruby
          faded
          :is-loading="isDeleting"
          @click="openDeleteConfirm"
        />
        <span v-else />
        <div class="flex gap-2">
          <Button
            :label="t('SCHEDULE.MODAL.CANCEL')"
            faded
            slate
            @click="handleCancel"
          />
          <Button
            :label="t('SCHEDULE.MODAL.SAVE')"
            :is-loading="isSubmitting"
            :disabled="!hasRequiredFields"
            @click="handleSubmit"
          />
        </div>
      </div>
    </template>
  </Dialog>

  <Dialog
    ref="deleteDialogRef"
    :title="t('SCHEDULE.MODAL.DELETE')"
    width="md"
    @close="closeDeleteConfirm"
  >
    <p class="text-sm text-n-text-body">
      {{ t('SCHEDULE.MODAL.DELETE_CONFIRM') }}
    </p>
    <template #footer>
      <div class="flex justify-end gap-2">
        <Button
          :label="t('SCHEDULE.MODAL.CANCEL')"
          faded
          slate
          @click="closeDeleteConfirm"
        />
        <Button
          :label="t('SCHEDULE.MODAL.DELETE')"
          ruby
          :is-loading="isDeleting"
          @click="handleDelete"
        />
      </div>
    </template>
  </Dialog>
</template>
