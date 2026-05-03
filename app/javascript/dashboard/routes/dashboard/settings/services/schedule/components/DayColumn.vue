<script setup>
import { computed, toRef } from 'vue';
import { format, isToday, isSameDay } from 'date-fns';
import { ru } from 'date-fns/locale';
import BookingCard from './BookingCard.vue';
import NowIndicator from './NowIndicator.vue';
import { layoutBookings, SLOT_HEIGHT } from '../composables/useCalendarLayout';
import { useColumnInteractions } from '../composables/useColumnInteractions';

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
  'bookingCreate',
  'bookingDragstart',
  'bookingDragend',
  'bookingResize',
]);

const dayName = computed(() => format(props.date, 'EEEE', { locale: ru }));
const dayNumber = computed(() => format(props.date, 'd'));
const isTodayDate = computed(() => isToday(props.date));

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

const dayBookings = computed(() =>
  props.bookings.filter(booking =>
    isSameDay(new Date(booking.scheduled_at), props.date)
  )
);

const positionedBookings = computed(() =>
  layoutBookings(dayBookings.value, {
    hoursStart: props.hoursRange.start,
    slotInterval: props.slotInterval,
  })
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

const { isDragging, ghostStyle, onMouseDown } = useColumnInteractions({
  slotInterval: toRef(props, 'slotInterval'),
  hoursStart: computed(() => props.hoursRange.start),
  date: toRef(props, 'date'),
  onSlot: time => emit('slotClick', { date: props.date, time }),
  onCreate: ({ startTime, durationMinutes }) =>
    emit('bookingCreate', {
      date: props.date,
      startTime,
      durationMinutes,
    }),
});

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
    newDate: props.date,
    newTime: time,
  });
};

const handleDragOver = e => {
  e.preventDefault();
};
</script>

<template>
  <div
    class="flex-1 min-w-[112px] sm:min-w-[140px] border-r border-n-border-glass-soft last:border-r-0"
  >
    <div
      class="h-12 px-2 flex flex-col items-center justify-center border-b border-n-border-glass-soft"
      :class="isTodayDate ? 'bg-n-brand' : ''"
    >
      <span
        class="text-xs font-medium uppercase"
        :class="isTodayDate ? 'text-white/90' : 'text-n-text-body/60'"
      >
        {{ dayName }}
      </span>
      <span
        class="text-sm font-semibold"
        :class="isTodayDate ? 'text-white' : 'text-n-text-display'"
      >
        {{ dayNumber }}
      </span>
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
        class="border-b border-n-border-glass-soft transition-colors"
        :class="{
          'bg-n-glass-strong': !workingSlotForTime(slot.hour, slot.minute),
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
        v-if="isTodayDate"
        :hours-range="hoursRange"
        :slot-interval="slotInterval"
      />
    </div>
  </div>
</template>
