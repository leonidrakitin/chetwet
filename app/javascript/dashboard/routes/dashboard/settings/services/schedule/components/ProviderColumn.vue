<script setup>
import { computed, toRef } from 'vue';
import { isToday } from 'date-fns';
import BookingCard from './BookingCard.vue';
import NowIndicator from './NowIndicator.vue';
import { layoutBookings, SLOT_HEIGHT } from '../composables/useCalendarLayout';
import { useColumnInteractions } from '../composables/useColumnInteractions';

const props = defineProps({
  provider: { type: Object, required: true },
  bookings: { type: Array, default: () => [] },
  hoursRange: { type: Object, default: () => ({ start: 9, end: 18 }) },
  slotInterval: { type: Number, default: 30 },
  date: { type: Date, required: true },
  workingHours: { type: Object, default: null },
});

const emit = defineEmits([
  'bookingClick',
  'slotClick',
  'bookingCreate',
  'bookingDragstart',
  'bookingDragend',
  'bookingResize',
]);

const timeSlots = computed(() => {
  const slots = [];
  const { start, end } = props.hoursRange;
  for (let hour = start; hour < end; hour += 1) {
    for (let minute = 0; minute < 60; minute += props.slotInterval) {
      slots.push({ hour, minute });
    }
  }
  return slots;
});

const workingSlotForTime = (hour, minute) => {
  if (!props.workingHours?.slots) return true;
  const timeStr = `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
  return props.workingHours.slots.some(
    slot => timeStr >= slot.start && timeStr < slot.end
  );
};

const positionedBookings = computed(() =>
  layoutBookings(props.bookings, {
    hoursStart: props.hoursRange.start,
    slotInterval: props.slotInterval,
  })
);

const { isDragging, ghostStyle, onMouseDown } = useColumnInteractions({
  slotInterval: toRef(props, 'slotInterval'),
  hoursStart: computed(() => props.hoursRange.start),
  date: toRef(props, 'date'),
  onSlot: time => emit('slotClick', { providerId: props.provider.id, time }),
  onCreate: ({ startTime, durationMinutes }) =>
    emit('bookingCreate', {
      providerId: props.provider.id,
      startTime,
      durationMinutes,
    }),
});

const isTodayCol = computed(() => isToday(props.date));

const handleDrop = e => {
  e.preventDefault();
  const bookingId = e.dataTransfer.getData('text/plain');
  if (!bookingId) return;
  const rect = e.currentTarget.getBoundingClientRect();
  const y = Math.max(0, e.clientY - rect.top);
  const pxPerMin = SLOT_HEIGHT / props.slotInterval;
  const mins = Math.round(y / pxPerMin / 5) * 5;
  const time = new Date(props.date);
  time.setHours(props.hoursRange.start, 0, 0, 0);
  time.setTime(time.getTime() + mins * 60000);
  emit('bookingDragend', {
    bookingId,
    newProviderId: props.provider.id,
    newTime: time,
  });
};

const handleDragOver = e => {
  e.preventDefault();
};
</script>

<template>
  <div
    class="shrink-0 w-[calc((100vw-3rem)/2)] sm:w-auto sm:flex-1 sm:min-w-[120px] border-r border-n-weak last:border-r-0"
  >
    <div
      class="h-12 px-2 flex items-center justify-center border-b border-n-weak bg-n-solid-1"
    >
      <span class="text-sm font-medium text-n-slate-12 truncate">{{
        provider.name
      }}</span>
    </div>

    <div
      class="relative select-none"
      @mousedown="onMouseDown"
      @drop="handleDrop"
      @dragover="handleDragOver"
    >
      <div
        v-for="slot in timeSlots"
        :key="`${slot.hour}-${slot.minute}`"
        class="border-b border-n-weak transition-colors"
        :class="{
          'bg-n-solid-2': !workingSlotForTime(slot.hour, slot.minute),
          'bg-n-slate-2': workingSlotForTime(slot.hour, slot.minute),
        }"
        :style="`height: ${SLOT_HEIGHT}px;`"
      />

      <div
        v-if="isDragging && ghostStyle"
        class="pointer-events-none absolute left-1 right-1 rounded-md border-2 border-dashed border-n-brand bg-n-brand/10 z-20"
        :style="ghostStyle"
      />

      <BookingCard
        v-for="{ booking, layout } in positionedBookings"
        :key="booking.id"
        :booking="booking"
        :slot-interval="slotInterval"
        :layout="layout"
        @click="emit('bookingClick', booking)"
        @dragstart="(e, b) => emit('bookingDragstart', e, b)"
        @dragend="emit('bookingDragend', $event)"
        @resize="emit('bookingResize', $event)"
      />

      <NowIndicator
        v-if="isTodayCol"
        :hours-range="hoursRange"
        :slot-interval="slotInterval"
      />
    </div>
  </div>
</template>
