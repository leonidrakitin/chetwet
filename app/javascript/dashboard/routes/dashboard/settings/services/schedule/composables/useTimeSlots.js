import { computed } from 'vue';
import {
  format,
  parse,
  setHours,
  setMinutes,
  addMinutes,
  differenceInMinutes,
  startOfDay,
  getDay,
} from 'date-fns';

const DAYS_OF_WEEK = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
];

export function useTimeSlots(schedule, selectedDate) {
  const workingHoursForDay = computed(() => {
    if (!schedule.value || !selectedDate.value) return null;
    const dayName = DAYS_OF_WEEK[getDay(selectedDate.value)];
    return (
      schedule.value.working_hours?.[dayName] || { enabled: false, slots: [] }
    );
  });

  const isEnabledDay = computed(
    () => workingHoursForDay.value?.enabled ?? false
  );

  const slotInterval = computed(
    () => schedule.value?.slot_interval_minutes || 30
  );

  const timezone = computed(() => schedule.value?.timezone || 'UTC');

  const breaks = computed(() => schedule.value?.breaks || []);

  const holidays = computed(() => schedule.value?.holidays || []);

  const isHoliday = computed(() => {
    if (!holidays.value.length || !selectedDate.value) return false;
    const dateStr = format(selectedDate.value, 'yyyy-MM-dd');
    return holidays.value.some(h => h.date === dateStr);
  });

  const isTimeInBreak = time => {
    const timeStr = format(time, 'HH:mm');
    return breaks.value.some(brk => timeStr >= brk.start && timeStr < brk.end);
  };

  const generateTimeSlots = (date, hours) => {
    if (!hours?.slots?.length) return [];
    const slots = [];
    const interval = slotInterval.value;
    hours.slots.forEach(slotConfig => {
      const startTime = parse(slotConfig.start, 'HH:mm', date);
      const endTime = parse(slotConfig.end, 'HH:mm', date);
      let current = startTime;
      while (current < endTime) {
        slots.push({
          time: current,
          formattedTime: format(current, 'HH:mm'),
          isBreak: isTimeInBreak(current),
        });
        current = addMinutes(current, interval);
      }
    });
    return slots;
  };

  const timeSlots = computed(() => {
    if (!selectedDate.value || !isEnabledDay.value || isHoliday.value)
      return [];
    return generateTimeSlots(selectedDate.value, workingHoursForDay.value);
  });

  const minTime = computed(() => {
    if (!workingHoursForDay.value?.slots?.length) return null;
    const starts = workingHoursForDay.value.slots.map(s => s.start);
    if (!starts.length) return null;
    return parse(starts[0], 'HH:mm', selectedDate.value || new Date());
  });

  const maxTime = computed(() => {
    if (!workingHoursForDay.value?.slots?.length) return null;
    const ends = workingHoursForDay.value.slots.map(s => s.end);
    if (!ends.length) return null;
    return parse(
      ends[ends.length - 1],
      'HH:mm',
      selectedDate.value || new Date()
    );
  });

  const hoursRange = computed(() => {
    if (!minTime.value || !maxTime.value) return { start: 9, end: 18 };
    return {
      start: minTime.value.getHours(),
      end: maxTime.value.getHours() + 1,
    };
  });

  return {
    workingHoursForDay,
    isEnabledDay,
    slotInterval,
    timezone,
    breaks,
    holidays,
    isHoliday,
    timeSlots,
    minTime,
    maxTime,
    hoursRange,
    generateTimeSlots,
    isTimeInBreak,
  };
}

export function useBookingPosition(booking, slotInterval, hoursRange, date) {
  const position = computed(() => {
    if (!booking.value || !slotInterval.value || !date.value) return null;
    const scheduledAt = new Date(booking.value.scheduled_at);
    const startHour = hoursRange.value?.start ?? 9;
    const dayStart = setHours(
      setMinutes(startOfDay(scheduledAt), 0),
      startHour
    );
    const topMinutes = differenceInMinutes(scheduledAt, dayStart);
    const heightMinutes =
      booking.value.total_duration_minutes || slotInterval.value;
    const slotHeight = 48;
    const minutesToPixels = minutes =>
      (minutes / slotInterval.value) * slotHeight;
    return {
      top: minutesToPixels(topMinutes),
      height: minutesToPixels(heightMinutes),
    };
  });
  return { position };
}

export function getBookingsForSlot(bookings, slotTime) {
  return bookings.filter(booking => {
    const scheduledAt = new Date(booking.scheduled_at);
    const endAt = new Date(booking.end_time);
    return scheduledAt <= slotTime && endAt > slotTime;
  });
}

export function isBookingInSlot(booking, slotTime) {
  const scheduledAt = new Date(booking.scheduled_at);
  return format(scheduledAt, 'HH:mm') === format(slotTime, 'HH:mm');
}

export function groupBookingsByProvider(bookings) {
  const grouped = {};
  bookings.forEach(booking => {
    const providerId = booking.service_provider?.id;
    if (!grouped[providerId]) grouped[providerId] = [];
    grouped[providerId].push(booking);
  });
  return grouped;
}

export function groupBookingsByDate(bookings) {
  const grouped = {};
  bookings.forEach(booking => {
    const dateKey = format(new Date(booking.scheduled_at), 'yyyy-MM-dd');
    if (!grouped[dateKey]) grouped[dateKey] = [];
    grouped[dateKey].push(booking);
  });
  return grouped;
}
