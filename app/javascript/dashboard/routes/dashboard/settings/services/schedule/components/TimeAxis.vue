<script setup>
import { computed } from 'vue';
import { format, setHours, setMinutes } from 'date-fns';

const props = defineProps({
  hoursRange: { type: Object, default: () => ({ start: 9, end: 18 }) },
  slotInterval: { type: Number, default: 30 },
});

const slotHeight = 48;

const timeSlots = computed(() => {
  const slots = [];
  const { start, end } = props.hoursRange;
  for (let hour = start; hour < end; hour += 1) {
    for (let minute = 0; minute < 60; minute += props.slotInterval) {
      const time = setHours(setMinutes(new Date(), minute), hour);
      slots.push({ hour, minute, label: format(time, 'HH:mm') });
    }
  }
  return slots;
});
</script>

<template>
  <div class="flex-shrink-0 w-12 sm:w-16 border-r border-n-weak">
    <div class="h-12 border-b border-n-weak" />
    <div class="relative">
      <div
        v-for="slot in timeSlots"
        :key="`${slot.hour}-${slot.minute}`"
        class="flex items-start justify-end pr-2 text-xs text-n-slate-10"
        :style="`height: ${slotHeight}px;`"
      >
        {{ slot.label }}
      </div>
    </div>
  </div>
</template>
