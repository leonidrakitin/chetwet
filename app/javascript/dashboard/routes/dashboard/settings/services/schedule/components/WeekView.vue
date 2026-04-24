<script setup>
import { computed } from 'vue';
import { startOfWeek, addDays } from 'date-fns';
import TimeAxis from './TimeAxis.vue';
import DayColumn from './DayColumn.vue';
import { useTimeSlots } from '../composables/useTimeSlots';

const props = defineProps({
  date: { type: Date, required: true },
  providerId: { type: [Number, String], required: true },
  bookings: { type: Array, default: () => [] },
  schedule: { type: Object, default: null },
});

const emit = defineEmits([
  'bookingClick',
  'slotClick',
  'bookingCreate',
  'bookingMove',
  'bookingResize',
]);

const { slotInterval, hoursRange } = useTimeSlots(
  computed(() => props.schedule),
  computed(() => props.date)
);

const weekDays = computed(() => {
  const start = startOfWeek(props.date, { weekStartsOn: 1 });
  const days = [];
  for (let i = 0; i < 7; i += 1) {
    days.push(addDays(start, i));
  }
  return days;
});

const providerBookings = computed(() =>
  props.bookings.filter(
    booking => booking.service_provider?.id === Number(props.providerId)
  )
);

const handleSlotClick = ({ date, time }) => {
  emit('slotClick', { providerId: props.providerId, date, time });
};

const handleBookingCreate = ({ date, startTime, durationMinutes }) => {
  emit('bookingCreate', {
    providerId: props.providerId,
    date,
    startTime,
    durationMinutes,
  });
};

const handleBookingMove = ({ bookingId, newDate, newTime }) => {
  emit('bookingMove', {
    bookingId,
    newProviderId: Number(props.providerId),
    newScheduledAt: newTime,
    newDate,
  });
};
</script>

<template>
  <div
    class="flex w-full min-w-0 overflow-x-auto overflow-y-visible [scrollbar-gutter:stable]"
  >
    <TimeAxis :hours-range="hoursRange" :slot-interval="slotInterval" />

    <div class="flex flex-1 min-w-max">
      <DayColumn
        v-for="day in weekDays"
        :key="day.toISOString()"
        :date="day"
        :bookings="providerBookings"
        :hours-range="hoursRange"
        :slot-interval="slotInterval"
        :working-hours="schedule?.working_hours"
        @booking-click="$emit('bookingClick', $event)"
        @slot-click="handleSlotClick"
        @booking-create="handleBookingCreate"
        @booking-dragend="handleBookingMove"
        @booking-resize="$emit('bookingResize', $event)"
      />
    </div>
  </div>
</template>
