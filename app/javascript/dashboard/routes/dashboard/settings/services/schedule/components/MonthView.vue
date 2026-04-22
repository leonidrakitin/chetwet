<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  format,
  startOfMonth,
  endOfMonth,
  eachDayOfInterval,
  isSameMonth,
  isSameDay,
  isToday,
  getDay,
} from 'date-fns';
const props = defineProps({
  date: { type: Date, required: true },
  bookings: { type: Array, default: () => [] },
  schedule: { type: Object, default: null },
});

const emit = defineEmits(['dateSelect', 'bookingClick']);

const { t } = useI18n();

const DAYS_OF_WEEK = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

const monthStart = computed(() => startOfMonth(props.date));
const monthEnd = computed(() => endOfMonth(props.date));

const calendarDays = computed(() => {
  const days = eachDayOfInterval({
    start: monthStart.value,
    end: monthEnd.value,
  });
  const firstDayOfWeek = (getDay(monthStart.value) + 6) % 7;

  const paddingDays = Array(firstDayOfWeek).fill(null);

  return [...paddingDays, ...days];
});

const weeks = computed(() => {
  const result = [];
  const days = calendarDays.value;

  for (let i = 0; i < days.length; i += 7) {
    result.push(days.slice(i, i + 7));
  }

  return result;
});

const getBookingsForDay = day => {
  if (!day) return [];
  const dateStr = format(day, 'yyyy-MM-dd');
  return props.bookings.filter(booking => {
    const bookingDate = format(new Date(booking.scheduled_at), 'yyyy-MM-dd');
    return bookingDate === dateStr;
  });
};

const isHoliday = day => {
  if (!day || !props.schedule?.holidays) return false;
  const dateStr = format(day, 'yyyy-MM-dd');
  return props.schedule.holidays.some(h => h.date === dateStr);
};

const DAY_NAMES = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
];

const isDayExplicitlyDisabled = day => {
  if (!day || !props.schedule?.working_hours) return false;
  return (
    props.schedule.working_hours[DAY_NAMES[getDay(day)]]?.enabled === false
  );
};

const handleDayClick = day => {
  if (day) {
    emit('dateSelect', day);
  }
};

const handleBookingClick = (booking, event) => {
  event.stopPropagation();
  emit('bookingClick', booking);
};

const getStatusColor = status => {
  const colors = {
    pending: 'bg-yellow-100 text-yellow-800',
    confirmed: 'bg-blue-100 text-blue-800',
    completed: 'bg-green-100 text-green-800',
    cancelled: 'bg-red-100 text-red-800',
  };
  return colors[status] || 'bg-gray-100 text-gray-800';
};
</script>

<template>
  <div class="flex flex-col w-full">
    <div class="grid grid-cols-7 border-b border-n-weak">
      <div
        v-for="day in DAYS_OF_WEEK"
        :key="day"
        class="py-2 text-center text-sm font-medium text-n-slate-10"
      >
        {{ day }}
      </div>
    </div>

    <div class="flex-1 grid grid-rows-6 border-l border-t border-n-weak">
      <div
        v-for="(week, weekIndex) in weeks"
        :key="weekIndex"
        class="grid grid-cols-7 border-b border-n-weak"
      >
        <div
          v-for="(day, dayIndex) in week"
          :key="dayIndex"
          class="min-h-[80px] p-1 border-r border-n-weak cursor-pointer hover:bg-n-solid-2 transition-colors"
          :class="{
            'bg-n-solid-1': day && isSameMonth(day, date),
            'bg-n-solid-3': day && !isSameMonth(day, date),
            'ring-2 ring-n-brand ring-inset': day && isSameDay(day, date),
          }"
          @click="handleDayClick(day)"
        >
          <div v-if="day" class="flex flex-col h-full">
            <div
              class="flex items-center justify-center w-6 h-6 text-sm rounded-full"
              :class="{
                'bg-n-brand text-white': isToday(day),
                'text-n-slate-12': !isToday(day) && isSameMonth(day, date),
                'text-n-slate-10': !isToday(day) && !isSameMonth(day, date),
              }"
            >
              {{ format(day, 'd') }}
            </div>

            <div class="flex-1 overflow-y-auto mt-1 space-y-0.5">
              <div
                v-for="booking in getBookingsForDay(day).slice(0, 3)"
                :key="booking.id"
                class="text-xs px-1 py-0.5 rounded truncate cursor-pointer"
                :class="getStatusColor(booking.status)"
                @click="handleBookingClick(booking, $event)"
              >
                {{ format(new Date(booking.scheduled_at), 'HH:mm') }}
                {{ booking.contact?.name || t('SCHEDULE.NO_CONTACT') }}
              </div>
              <div
                v-if="getBookingsForDay(day).length > 3"
                class="text-xs text-n-slate-10 px-1"
              >
                +{{ getBookingsForDay(day).length - 3 }}
                {{ t('SCHEDULE.MORE') }}
              </div>
            </div>

            <div v-if="isHoliday(day)" class="text-xs text-red-500 mt-auto">
              {{ t('SCHEDULE.HOLIDAY') }}
            </div>
            <div
              v-else-if="isSameMonth(day, date) && isDayExplicitlyDisabled(day)"
              class="text-xs text-n-slate-10 mt-auto"
            >
              {{ t('SCHEDULE.NOT_WORKING_DAY') }}
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
