<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  booking: {
    type: Object,
    required: true,
  },
  slotInterval: {
    type: Number,
    default: 30,
  },
  hoursRange: {
    type: Object,
    default: () => ({ start: 9, end: 18 }),
  },
  isDragging: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['click', 'dragstart', 'dragend']);

const { t } = useI18n();

const statusColors = {
  pending: 'bg-n-amber-5 border-n-amber-9',
  confirmed: 'bg-n-blue-5 border-n-blue-9',
  completed: 'bg-n-teal-5 border-n-teal-9',
  cancelled: 'bg-n-ruby-5 border-n-ruby-9',
};

const cardPosition = computed(() => {
  const scheduledAt = new Date(props.booking.scheduled_at);
  const startHour = props.hoursRange?.start ?? 9;
  const dayStart = new Date(scheduledAt);
  dayStart.setHours(startHour, 0, 0, 0);

  const minutesFromStart =
    (scheduledAt.getHours() - startHour) * 60 + scheduledAt.getMinutes();

  const duration = props.booking.total_duration_minutes || props.slotInterval;
  const slotHeight = 48;
  const pixelsPerMinute = slotHeight / props.slotInterval;

  return {
    top: minutesFromStart * pixelsPerMinute,
    height: duration * pixelsPerMinute - 2,
  };
});

const contactName = computed(() => {
  return props.booking.contact?.name || t('SCHEDULE.NO_CONTACT');
});

const contactPhone = computed(() => {
  return props.booking.contact?.phone_number || '';
});

const servicesList = computed(() => {
  return props.booking.services?.map(s => s.name).join(', ') || '';
});

const isFirstBooking = computed(() => {
  return props.booking.contact?.is_first_booking ?? false;
});

const statusClass = computed(() => {
  return statusColors[props.booking.status] || statusColors.pending;
});

const handleDragStart = e => {
  emit('dragstart', e, props.booking);
  e.dataTransfer.effectAllowed = 'move';
  e.dataTransfer.setData('text/plain', props.booking.id);
};

const handleClick = () => {
  emit('click', props.booking);
};
</script>

<template>
  <div
    class="absolute left-1 right-1 rounded-md border-l-2 cursor-pointer transition-all hover:shadow-md overflow-hidden group"
    :class="[statusClass, { 'opacity-60 cursor-grabbing': isDragging }]"
    :style="`top: ${cardPosition.top}px; height: ${cardPosition.height}px; min-height: 48px;`"
    draggable="true"
    @dragstart="handleDragStart"
    @dragend="$emit('dragend')"
    @click="handleClick"
  >
    <div class="p-1.5 h-full flex flex-col">
      <div class="flex items-start justify-between gap-1">
        <span class="text-xs font-medium text-n-slate-12 truncate">
          {{ servicesList }}
        </span>
        <span
          v-if="isFirstBooking"
          class="flex-shrink-0 px-1 py-0.5 text-[10px] font-medium rounded bg-n-brand text-white"
        >
          {{ t('SCHEDULE.FIRST_BOOKING') }}
        </span>
      </div>

      <div class="mt-0.5 text-xs text-n-slate-11 truncate">
        {{ contactName }}
        <span v-if="contactPhone" class="text-n-slate-10">
          {{ ' · ' }}{{ contactPhone }}
        </span>
      </div>

      <div
        v-if="booking.customer_notes"
        class="mt-auto pt-0.5 text-[10px] text-n-slate-10 truncate"
      >
        {{ booking.customer_notes }}
      </div>
    </div>
  </div>
</template>
