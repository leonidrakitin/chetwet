<script setup>
import { computed } from 'vue';
import TimeAxis from './TimeAxis.vue';
import ProviderColumn from './ProviderColumn.vue';
import { useTimeSlots } from '../composables/useTimeSlots';

const props = defineProps({
  date: { type: Date, required: true },
  providers: { type: Array, default: () => [] },
  bookings: { type: Array, default: () => [] },
  schedule: { type: Object, default: null },
});

const emit = defineEmits(['bookingClick', 'slotClick', 'bookingMove']);

const {
  slotInterval,
  hoursRange,
  workingHoursForDay,
  isEnabledDay,
  isHoliday,
} = useTimeSlots(
  computed(() => props.schedule),
  computed(() => props.date)
);

const dayWorkingHours = computed(() => workingHoursForDay.value);

const providerBookings = computed(() => {
  const grouped = {};
  props.providers.forEach(provider => {
    grouped[provider.id] = props.bookings.filter(
      booking => booking.service_provider?.id === provider.id
    );
  });
  return grouped;
});

const handleSlotClick = ({ providerId, time }) => {
  emit('slotClick', { providerId, date: props.date, time });
};

const handleBookingMove = ({ bookingId, newProviderId, newTime }) => {
  emit('bookingMove', { bookingId, newProviderId, newScheduledAt: newTime });
};
</script>

<template>
  <div class="flex flex-1 overflow-hidden">
    <TimeAxis :hours-range="hoursRange" :slot-interval="slotInterval" />

    <div class="flex flex-1 overflow-x-auto">
      <div
        v-if="!isEnabledDay || isHoliday"
        class="flex-1 flex items-center justify-center"
      >
        <div class="text-center text-n-slate-11">
          <p class="text-lg font-medium">
            {{
              isHoliday
                ? $t('SCHEDULE.HOLIDAY')
                : $t('SCHEDULE.NOT_WORKING_DAY')
            }}
          </p>
        </div>
      </div>

      <template v-else>
        <ProviderColumn
          v-for="provider in providers"
          :key="provider.id"
          :provider="provider"
          :bookings="providerBookings[provider.id] || []"
          :hours-range="hoursRange"
          :slot-interval="slotInterval"
          :date="date"
          :working-hours="dayWorkingHours"
          @booking-click="$emit('bookingClick', $event)"
          @slot-click="handleSlotClick"
          @booking-dragend="handleBookingMove"
        />
      </template>
    </div>
  </div>
</template>
