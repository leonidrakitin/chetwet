<script setup>
import { computed } from 'vue';
import { format } from 'date-fns';
import BookingCard from './BookingCard.vue';

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
  'bookingDragstart',
  'bookingDragend',
]);

const slotHeight = 48;

const timeSlots = computed(() => {
  const slots = [];
  const { start, end } = props.hoursRange;
  for (let hour = start; hour < end; hour += 1) {
    for (let minute = 0; minute < 60; minute += props.slotInterval) {
      const time = new Date(props.date);
      time.setHours(hour, minute, 0, 0);
      slots.push({ time, hour, minute, formattedTime: format(time, 'HH:mm') });
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

const handleSlotClick = slot => {
  emit('slotClick', { providerId: props.provider.id, time: slot.time });
};

const handleDrop = e => {
  e.preventDefault();
  const bookingId = e.dataTransfer.getData('text/plain');
  const rect = e.currentTarget.getBoundingClientRect();
  const y = e.clientY - rect.top;
  const slotIndex = Math.floor(y / slotHeight);
  const slot = timeSlots.value[slotIndex];
  if (slot) {
    emit('bookingDragend', {
      bookingId,
      newProviderId: props.provider.id,
      newTime: slot.time,
    });
  }
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

    <div class="relative" @drop="handleDrop" @dragover="handleDragOver">
      <div
        v-for="slot in timeSlots"
        :key="`${slot.hour}-${slot.minute}`"
        class="border-b border-n-weak cursor-pointer hover:bg-n-alpha-1 transition-colors"
        :class="{
          'bg-n-solid-2': !workingSlotForTime(slot.hour, slot.minute),
          'bg-n-slate-2': workingSlotForTime(slot.hour, slot.minute),
        }"
        :style="`height: ${slotHeight}px;`"
        @click="handleSlotClick(slot)"
      />

      <BookingCard
        v-for="booking in bookings"
        :key="booking.id"
        :booking="booking"
        :slot-interval="slotInterval"
        :hours-range="hoursRange"
        @click="emit('bookingClick', booking)"
        @dragstart="(e, b) => emit('bookingDragstart', e, b)"
        @dragend="emit('bookingDragend', $event)"
      />
    </div>
  </div>
</template>
