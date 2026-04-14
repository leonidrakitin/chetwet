<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { format } from 'date-fns';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  booking: { type: Object, default: null },
  initialProviderId: { type: [Number, String], default: null },
  initialTime: { type: Date, default: null },
  providers: { type: Array, default: () => [] },
  services: { type: Array, default: () => [] },
});

const emit = defineEmits(['close', 'saved']);

const { t } = useI18n();
const store = useStore();

const isEditing = computed(() => !!props.booking);
const STATUS_OPTIONS = ['pending', 'confirmed', 'completed', 'cancelled'];
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
const contactSearch = ref('');
const contactResults = ref([]);
const isSearchingContacts = ref(false);
const selectedContact = ref(null);
const selectedServices = ref([]);
const isSubmitting = ref(false);
const isDeleting = ref(false);
const showDeleteConfirm = ref(false);

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
  contactSearch.value = '';
  contactResults.value = [];
  showDeleteConfirm.value = false;
};

watch(
  () => props.show,
  newShow => {
    if (newShow) initForm();
  }
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
    showDeleteConfirm.value = false;
  }
};

const handleCancel = () => emit('close');

const searchContacts = async query => {
  if (!query || query.length < 2) {
    contactResults.value = [];
    return;
  }
  isSearchingContacts.value = true;
  try {
    const response = await store.dispatch('contacts/search', query);
    contactResults.value = response.data || [];
  } catch {
    contactResults.value = [];
  } finally {
    isSearchingContacts.value = false;
  }
};

const selectContact = contact => {
  selectedContact.value = contact;
  form.value.contact_id = contact.id;
  contactSearch.value = '';
  contactResults.value = [];
};

const toggleService = service => {
  const index = selectedServices.value.findIndex(s => s.id === service.id);
  if (index === -1) selectedServices.value.push(service);
  else selectedServices.value.splice(index, 1);
};

const isServiceSelected = serviceId =>
  selectedServices.value.some(s => s.id === serviceId);
</script>

<template>
  <Dialog :show="show" :title="title" @close="handleCancel">
    <template #body>
      <div class="flex flex-col gap-4">
        <div>
          <label class="block text-sm font-medium text-n-slate-12 mb-1">{{
            t('SCHEDULE.MODAL.PROVIDER')
          }}</label>
          <select
            v-model="form.service_provider_id"
            class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
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
          <label class="block text-sm font-medium text-n-slate-12 mb-1">{{
            t('SCHEDULE.MODAL.DATE_TIME')
          }}</label>
          <input
            v-model="form.scheduled_at"
            type="datetime-local"
            class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-n-slate-12 mb-1">{{
            t('SCHEDULE.MODAL.CONTACT')
          }}</label>
          <div
            v-if="selectedContact"
            class="flex items-center gap-2 px-3 py-2 bg-n-solid-2 rounded-md"
          >
            <span class="text-sm text-n-slate-12">{{
              selectedContact.name
            }}</span>
            <button
              class="text-n-slate-10 hover:text-n-slate-12"
              @click="
                selectedContact = null;
                form.contact_id = null;
              "
            >
              {{ '×' }}
            </button>
          </div>
          <div v-else class="relative">
            <input
              v-model="contactSearch"
              type="text"
              :placeholder="t('SCHEDULE.MODAL.SEARCH_CONTACT')"
              class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
              @input="searchContacts($event.target.value)"
            />
            <div
              v-if="contactResults.length"
              class="absolute z-10 w-full mt-1 bg-n-solid-1 border border-n-weak rounded-md shadow-lg max-h-40 overflow-y-auto"
            >
              <button
                v-for="contact in contactResults"
                :key="contact.id"
                class="w-full px-3 py-2 text-left text-sm hover:bg-n-solid-2"
                @click="selectContact(contact)"
              >
                {{ contact.name }}
                <span v-if="contact.phone_number" class="text-n-slate-10">
                  {{ ' · ' }}{{ contact.phone_number }}
                </span>
              </button>
            </div>
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium text-n-slate-12 mb-1">{{
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
                  : 'bg-n-solid-1 border-n-weak text-n-slate-12 hover:border-n-brand'
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
          <label class="block text-sm font-medium text-n-slate-12 mb-1">{{
            t('SCHEDULE.MODAL.CUSTOMER_NOTES')
          }}</label>
          <textarea
            v-model="form.customer_notes"
            rows="2"
            class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand resize-none"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-n-slate-12 mb-1">{{
            t('SCHEDULE.MODAL.INTERNAL_NOTES')
          }}</label>
          <textarea
            v-model="form.internal_notes"
            rows="2"
            class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand resize-none"
          />
        </div>

        <div v-if="isEditing">
          <label class="block text-sm font-medium text-n-slate-12 mb-1">{{
            t('SCHEDULE.MODAL.STATUS')
          }}</label>
          <select
            v-model="form.status"
            class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
          >
            <option
              v-for="status in STATUS_OPTIONS"
              :key="status"
              :value="status"
            >
              {{ t(`SCHEDULE.STATUS.${status.toUpperCase()}`) }}
            </option>
          </select>
        </div>

        <div v-if="isEditing && form.status === 'cancelled'">
          <label class="block text-sm font-medium text-n-slate-12 mb-1">{{
            t('SCHEDULE.MODAL.CANCEL_REASON')
          }}</label>
          <textarea
            v-model="form.cancellation_reason"
            rows="2"
            class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand resize-none"
          />
        </div>
      </div>
    </template>

    <template #footer>
      <div class="flex justify-between gap-2">
        <Button
          v-if="isEditing"
          :label="t('SCHEDULE.MODAL.DELETE')"
          icon="i-lucide-trash-2"
          ruby
          faded
          :is-loading="isDeleting"
          @click="showDeleteConfirm = true"
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
            @click="handleSubmit"
          />
        </div>
      </div>
    </template>
  </Dialog>

  <Dialog
    :show="showDeleteConfirm"
    :title="t('SCHEDULE.MODAL.DELETE')"
    @close="showDeleteConfirm = false"
  >
    <template #body>
      <p class="text-sm text-n-slate-11">
        {{ t('SCHEDULE.MODAL.DELETE_CONFIRM') }}
      </p>
    </template>
    <template #footer>
      <div class="flex justify-end gap-2">
        <Button
          :label="t('SCHEDULE.MODAL.CANCEL')"
          faded
          slate
          @click="showDeleteConfirm = false"
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
