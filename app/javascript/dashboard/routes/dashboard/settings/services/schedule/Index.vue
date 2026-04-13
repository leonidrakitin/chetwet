<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { format, startOfWeek, endOfWeek } from 'date-fns';
import ScheduleHeader from './components/ScheduleHeader.vue';
import DayView from './components/DayView.vue';
import WeekView from './components/WeekView.vue';
import BookingModal from './components/BookingModal.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import SettingsLayout from '../../SettingsLayout.vue';
import BaseSettingsHeader from '../../components/BaseSettingsHeader.vue';

const store = useStore();
const { t } = useI18n();

const currentDate = ref(new Date());
const viewMode = ref('day');
const selectedProviderId = ref(null);
const showBookingModal = ref(false);
const selectedBooking = ref(null);
const initialProviderId = ref(null);
const initialTime = ref(null);

const schedule = computed(() => store.getters['services/getSchedule']);
const calendarBookings = computed(
  () => store.getters['services/getCalendarBookings']
);
const calendarProviders = computed(
  () => store.getters['services/getCalendarProviders']
);
const uiFlags = computed(() => store.getters['services/getUIFlags']);
const services = computed(() => store.getters['services/getServices']);

const isLoading = computed(
  () => uiFlags.value.isFetchingCalendar || uiFlags.value.isFetchingSchedule
);

const activeProviders = computed(() => {
  return calendarProviders.value.filter(p => p.active);
});

const fetchCalendarData = async () => {
  let startDate;
  let endDate;

  if (viewMode.value === 'day') {
    startDate = currentDate.value;
    endDate = currentDate.value;
  } else {
    startDate = startOfWeek(currentDate.value, { weekStartsOn: 1 });
    endDate = endOfWeek(currentDate.value, { weekStartsOn: 1 });
  }

  try {
    await store.dispatch('services/fetchCalendar', {
      start_date: format(startDate, 'yyyy-MM-dd'),
      end_date: format(endDate, 'yyyy-MM-dd'),
      provider_id:
        viewMode.value === 'week' ? selectedProviderId.value : undefined,
    });
  } catch (error) {
    useAlert(error.message || t('SCHEDULE.FETCH_ERROR'));
  }
};

const fetchServices = async () => {
  if (!services.value.length) {
    await store.dispatch('services/fetchServices');
  }
};

watch([currentDate, viewMode, selectedProviderId], () => {
  fetchCalendarData();
});

watch(viewMode, newMode => {
  if (
    newMode === 'week' &&
    !selectedProviderId.value &&
    activeProviders.value.length
  ) {
    selectedProviderId.value = activeProviders.value[0].id;
  }
});

onMounted(async () => {
  await Promise.all([fetchCalendarData(), fetchServices()]);

  if (activeProviders.value.length) {
    selectedProviderId.value = activeProviders.value[0].id;
  }
});

const handleSlotClick = ({ providerId, time }) => {
  selectedBooking.value = null;
  initialProviderId.value = providerId;
  initialTime.value = time;
  showBookingModal.value = true;
};

const handleBookingClick = booking => {
  selectedBooking.value = booking;
  initialProviderId.value = null;
  initialTime.value = null;
  showBookingModal.value = true;
};

const handleBookingMove = async ({
  bookingId,
  newProviderId,
  newScheduledAt,
}) => {
  try {
    await store.dispatch('services/updateBooking', {
      id: bookingId,
      booking: {
        service_provider_id: newProviderId,
        scheduled_at: newScheduledAt,
      },
    });
    await fetchCalendarData();
    useAlert(t('SCHEDULE.BOOKING_MOVED'));
  } catch (error) {
    useAlert(error.message || t('SCHEDULE.MOVE_ERROR'));
  }
};

const handleBookingSaved = () => {
  fetchCalendarData();
};

const closeModal = () => {
  showBookingModal.value = false;
  selectedBooking.value = null;
};
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('SCHEDULE.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('SCHEDULE.HEADER')"
        :description="$t('SCHEDULE.DESCRIPTION')"
        feature-name="services_schedule"
      />
    </template>

    <template #body>
      <div
        class="flex flex-col h-[calc(100vh-200px)] bg-n-solid-1 rounded-lg border border-n-weak"
      >
        <ScheduleHeader
          v-model:current-date="currentDate"
          v-model:view-mode="viewMode"
          v-model:selected-provider-id="selectedProviderId"
          :providers="activeProviders"
        />

        <div class="flex-1 overflow-hidden">
          <Spinner v-if="isLoading" class="m-auto" />

          <DayView
            v-else-if="viewMode === 'day'"
            :date="currentDate"
            :providers="activeProviders"
            :bookings="calendarBookings"
            :schedule="schedule"
            @booking-click="handleBookingClick"
            @slot-click="handleSlotClick"
            @booking-move="handleBookingMove"
          />

          <WeekView
            v-else
            :date="currentDate"
            :provider-id="selectedProviderId"
            :bookings="calendarBookings"
            :schedule="schedule"
            @booking-click="handleBookingClick"
            @slot-click="handleSlotClick"
            @booking-move="handleBookingMove"
          />
        </div>
      </div>
    </template>
  </SettingsLayout>

  <BookingModal
    :show="showBookingModal"
    :booking="selectedBooking"
    :initial-provider-id="initialProviderId"
    :initial-time="initialTime"
    :providers="activeProviders"
    :services="services"
    @close="closeModal"
    @saved="handleBookingSaved"
  />
</template>
