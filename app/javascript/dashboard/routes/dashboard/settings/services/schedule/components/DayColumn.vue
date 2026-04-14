<script setup>
import { computed } from 'vue';
import { format, isToday, isSameDay } from 'date-fns';
import { ru } from 'date-fns/locale';
import BookingCard from './BookingCard.vue';

const props = defineProps({
  date: { type: Date, required: true },
  bookings: { type: Array, default: () => [] },
  hoursRange: { type: Object, default: () => ({ start: 9, end: 18 }) },
  slotInterval: { type: Number, default: 30 },
  workingHours: { type: Object, default: null },
});

const emit = defineEmits([
  'bookingClick',
  'slotClick',
  'bookingDragstart',
  'bookingDragend',
]);

const slotHeight = 48;

const dayName = computed(() => format(props.date, 'EEEE', { locale: ru }));
const dayNumber = computed(() => format(props.date, 'd'));
const isTodayDate = computed(() => isToday(props.date));

const timeSlots = computed(() => {
  const slots = [];
  const { start, end } = props.hoursRange;
  for (let hour = start; hour < end; hour += 1) {
    for (let minute = 0; minute < 60; minute += props.slotInterval) {
      const time = new Date(props.date);
      time.setHours(hour, minute, 0, 0);
      slots.push({ time, hour, minute });
    }
  }
  return slots;
});

const dayBookings = computed(() =>
  props.bookings.filter(booking =>
    isSameDay(new Date(booking.scheduled_at), props.date)
  )
);

const workingSlotForTime = (hour, minute) => {
  if (!props.workingHours) return true;
  const dayStr = format(props.date, 'EEEE').toLowerCase();
  const dayConfig = props.workingHours[dayStr];
  if (!dayConfig?.enabled) return false;
  const timeStr = `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
  return dayConfig.slots.some(
    slot => timeStr >= slot.start && timeStr < slot.end
  );
};

const handleSlotClick = slot => {
  emit('slotClick', { date: props.date, time: slot.time });
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
      newDate: props.date,
      newTime: slot.time,
    });
  }
};

const handleDragOver = e => {
  e.preventDefault();
};
</script>

<template>
  <div class="flex-1 min-w-[140px] border-r border-n-weak last:border-r-0">
    <div
      class="h-12 px-2 flex flex-col items-center justify-center border-b border-n-weak"
      :class="isTodayDate ? 'bg-n-brand' : ''"
    >
      <span
        class="text-xs font-medium uppercase"
        :class="isTodayDate ? 'text-white/90' : 'text-n-slate-10'"
      >
        {{ dayName }}
      </span>
      <span
        class="text-sm font-semibold"
        :class="isTodayDate ? 'text-white' : 'text-n-slate-12'"
      >
        {{ dayNumber }}
      </span>
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
        v-for="booking in dayBookings"
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
