<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { SLOT_HEIGHT } from '../composables/useCalendarLayout';

const props = defineProps({
  booking: { type: Object, required: true },
  slotInterval: { type: Number, default: 30 },
  layout: { type: Object, required: true },
  isDragging: { type: Boolean, default: false },
});

const emit = defineEmits(['click', 'dragstart', 'dragend', 'resize']);

const { t } = useI18n();

const statusColors = {
  pending: 'bg-n-amber-5 border-n-amber-9',
  confirmed: 'bg-n-blue-5 border-n-blue-9',
  arrived: 'bg-n-teal-5 border-n-teal-9',
  completed: 'bg-n-teal-5 border-n-teal-9',
  cancelled: 'bg-n-ruby-5 border-n-ruby-9',
  no_show: 'bg-n-ruby-5 border-n-ruby-9',
};

const contactName = computed(
  () => props.booking.contact?.name || t('SCHEDULE.NO_CONTACT')
);
const contactPhone = computed(() => props.booking.contact?.phone_number || '');
const servicesList = computed(
  () => props.booking.services?.map(s => s.name).join(', ') || ''
);
const isFirstBooking = computed(
  () => props.booking.contact?.is_first_booking ?? false
);
const statusClass = computed(
  () => statusColors[props.booking.status] || statusColors.pending
);

const pxPerMinute = computed(() => SLOT_HEIGHT / props.slotInterval);
const resizingHeight = ref(null);
const resizingDurationRef = ref(null);
let resizeStartY = 0;

const onResizeMouseMove = e => {
  const baseHeight = props.layout.height;
  const baseDuration =
    props.booking.total_duration_minutes || props.slotInterval;
  const delta = e.clientY - resizeStartY;
  const newHeight = Math.max(baseHeight + delta, SLOT_HEIGHT / 2);
  const newDurationRaw = baseDuration + delta / pxPerMinute.value;
  const snapped = Math.max(Math.round(newDurationRaw / 5) * 5, 5);
  resizingHeight.value = newHeight;
  resizingDurationRef.value = snapped;
};

const rootStyle = computed(() => ({
  top: `${props.layout.top}px`,
  height: `${resizingHeight.value ?? props.layout.height}px`,
  left: `${props.layout.leftPct}%`,
  width: `${props.layout.widthPct}%`,
  zIndex: props.layout.zIndex,
}));

const handleDragStart = e => {
  emit('dragstart', e, props.booking);
  e.dataTransfer.effectAllowed = 'move';
  e.dataTransfer.setData('text/plain', String(props.booking.id));
};

const handleClick = () => emit('click', props.booking);

const onResizeMouseUp = () => {
  window.removeEventListener('mousemove', onResizeMouseMove);
  window.removeEventListener('mouseup', onResizeMouseUp);
  const duration = resizingDurationRef.value;
  resizingHeight.value = null;
  resizingDurationRef.value = null;
  if (duration && duration !== props.booking.total_duration_minutes) {
    emit('resize', { bookingId: props.booking.id, durationMinutes: duration });
  }
};

const startResize = e => {
  e.stopPropagation();
  e.preventDefault();
  resizeStartY = e.clientY;
  window.addEventListener('mousemove', onResizeMouseMove);
  window.addEventListener('mouseup', onResizeMouseUp);
};
</script>

<template>
  <div
    data-booking-card
    class="absolute rounded-md border-l-2 cursor-pointer transition-shadow hover:shadow-md overflow-hidden group"
    :class="[statusClass, { 'opacity-60 cursor-grabbing': isDragging }]"
    :style="rootStyle"
    draggable="true"
    @dragstart="handleDragStart"
    @dragend="$emit('dragend')"
    @click="handleClick"
    @mousedown.stop
  >
    <div class="p-1.5 h-full flex flex-col pointer-events-none">
      <div class="flex items-start justify-between gap-1">
        <span class="text-xs font-medium text-n-text-display truncate">
          {{ servicesList }}
        </span>
        <span
          v-if="isFirstBooking"
          class="flex-shrink-0 px-1 py-0.5 text-[10px] font-medium rounded bg-n-brand text-white"
        >
          {{ t('SCHEDULE.FIRST_BOOKING') }}
        </span>
      </div>

      <div class="mt-0.5 text-xs text-n-text-body truncate">
        {{ contactName }}
        <span v-if="contactPhone" class="text-n-text-body/60">
          {{ ' · ' }}{{ contactPhone }}
        </span>
      </div>

      <div
        v-if="booking.customer_notes"
        class="mt-auto pt-0.5 text-[10px] text-n-text-body/60 truncate"
      >
        {{ booking.customer_notes }}
      </div>
    </div>

    <div
      class="absolute inset-x-0 bottom-0 h-1.5 cursor-ns-resize bg-transparent hover:bg-n-alpha-2"
      @mousedown="startResize"
    />
  </div>
</template>
