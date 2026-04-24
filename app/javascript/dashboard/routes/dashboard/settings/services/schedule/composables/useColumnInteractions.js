import { ref, computed } from 'vue';
import { SLOT_HEIGHT } from './useCalendarLayout';

const DRAG_THRESHOLD_PX = 4;
const SNAP_MINUTES = 5;

const snap = (minutes, step) => Math.round(minutes / step) * step;

export function useColumnInteractions({
  slotInterval,
  hoursStart,
  date,
  onSlot,
  onCreate,
}) {
  const isDragging = ref(false);
  const startY = ref(0);
  const currentY = ref(0);
  const columnEl = ref(null);

  const pxPerMinute = computed(() => SLOT_HEIGHT / slotInterval.value);

  const yToMinutes = y => y / pxPerMinute.value;

  const minutesToTime = mins => {
    const base = new Date(date.value);
    base.setHours(hoursStart.value, 0, 0, 0);
    return new Date(base.getTime() + mins * 60000);
  };

  const ghostStyle = computed(() => {
    if (!isDragging.value) return null;
    const y1 = Math.min(startY.value, currentY.value);
    const y2 = Math.max(startY.value, currentY.value);
    const snappedTop = snap(yToMinutes(y1), SNAP_MINUTES) * pxPerMinute.value;
    const snappedBottom =
      snap(yToMinutes(y2), SNAP_MINUTES) * pxPerMinute.value;
    return {
      top: `${snappedTop}px`,
      height: `${Math.max(snappedBottom - snappedTop, SLOT_HEIGHT / 2)}px`,
    };
  });

  const handleMouseMove = e => {
    if (!columnEl.value) return;
    const rect = columnEl.value.getBoundingClientRect();
    currentY.value = Math.max(0, e.clientY - rect.top);
  };

  const handleMouseUp = () => {
    const delta = Math.abs(currentY.value - startY.value);
    if (delta < DRAG_THRESHOLD_PX) {
      const minutes = snap(yToMinutes(startY.value), SNAP_MINUTES);
      onSlot?.(minutesToTime(minutes));
    } else {
      const y1 = Math.min(startY.value, currentY.value);
      const y2 = Math.max(startY.value, currentY.value);
      const m1 = snap(yToMinutes(y1), SNAP_MINUTES);
      const m2 = snap(yToMinutes(y2), SNAP_MINUTES);
      const duration = Math.max(m2 - m1, slotInterval.value);
      onCreate?.({
        startTime: minutesToTime(m1),
        durationMinutes: duration,
      });
    }
    isDragging.value = false;
    window.removeEventListener('mousemove', handleMouseMove);
    window.removeEventListener('mouseup', handleMouseUp);
  };

  const onMouseDown = e => {
    if (e.button !== 0) return;
    if (e.target.closest('[data-booking-card]')) return;
    columnEl.value = e.currentTarget;
    const rect = columnEl.value.getBoundingClientRect();
    startY.value = e.clientY - rect.top;
    currentY.value = startY.value;
    isDragging.value = true;
    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseup', handleMouseUp);
  };

  return { isDragging, ghostStyle, onMouseDown };
}
