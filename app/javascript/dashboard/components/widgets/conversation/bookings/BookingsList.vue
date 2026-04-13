<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import BookingItem from './BookingItem.vue';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
});

const store = useStore();
const { t } = useI18n();

const bookings = ref([]);
const loading = ref(true);
const errorMessage = ref('');

const hasData = computed(() => bookings.value.length > 0);

const upcomingBookings = computed(() => {
  const now = new Date();
  return bookings.value
    .filter(b => new Date(b.scheduled_at) >= now && b.status !== 'cancelled')
    .sort((a, b) => new Date(a.scheduled_at) - new Date(b.scheduled_at));
});

const pastBookings = computed(() => {
  const now = new Date();
  return bookings.value
    .filter(b => new Date(b.scheduled_at) < now || b.status === 'cancelled')
    .sort((a, b) => new Date(b.scheduled_at) - new Date(b.scheduled_at));
});

const fetchBookings = async () => {
  if (!props.contactId) {
    bookings.value = [];
    loading.value = false;
    return;
  }

  loading.value = true;
  errorMessage.value = '';

  try {
    const response = await store.dispatch('services/fetchBookings', {
      contact_id: props.contactId,
    });
    bookings.value = response.data || [];
  } catch (error) {
    errorMessage.value = error.message || t('BOOKINGS.FETCH_ERROR');
  } finally {
    loading.value = false;
  }
};

watch(
  () => props.contactId,
  () => {
    fetchBookings();
  },
  { immediate: true }
);

const handleCancel = async bookingId => {
  try {
    await store.dispatch('services/cancelBooking', {
      id: bookingId,
      reason: t('BOOKINGS.CANCELLED_VIA_SIDEBAR'),
    });
    await fetchBookings();
  } catch (error) {
    throw new Error(error);
  }
};
</script>

<template>
  <div class="px-4 py-2 text-n-slate-12">
    <div v-if="loading" class="flex justify-center items-center p-4">
      <Spinner size="32" class="text-n-brand" />
    </div>

    <div v-else-if="errorMessage" class="text-center text-n-ruby-12 text-sm">
      {{ errorMessage }}
    </div>

    <div v-else>
      <div v-if="upcomingBookings.length" class="pb-3">
        <p
          class="pb-2 text-xs font-medium uppercase tracking-wide text-n-slate-10"
        >
          {{ $t('BOOKINGS.UPCOMING') }}
        </p>
        <BookingItem
          v-for="booking in upcomingBookings"
          :key="booking.id"
          :booking="booking"
          @cancel="handleCancel"
        />
      </div>

      <div v-if="pastBookings.length" class="flex flex-col gap-2 pt-1">
        <p class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
          {{ $t('BOOKINGS.PAST') }}
        </p>
        <BookingItem
          v-for="booking in pastBookings"
          :key="booking.id"
          :booking="booking"
          is-past
          @cancel="handleCancel"
        />
      </div>

      <div v-if="!hasData" class="text-center text-n-slate-11 text-sm">
        {{ $t('BOOKINGS.NO_BOOKINGS') }}
      </div>
    </div>
  </div>
</template>
