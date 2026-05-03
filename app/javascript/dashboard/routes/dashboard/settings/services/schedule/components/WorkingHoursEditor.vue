<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import DayScheduleRow from './DayScheduleRow.vue';

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
  holidays: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const DAYS = [
  {
    key: 'monday',
    label: 'MON',
    labelFullKey: 'SCHEDULE.DAYS.MONDAY',
    dayIndex: 0,
  },
  {
    key: 'tuesday',
    label: 'TUE',
    labelFullKey: 'SCHEDULE.DAYS.TUESDAY',
    dayIndex: 1,
  },
  {
    key: 'wednesday',
    label: 'WED',
    labelFullKey: 'SCHEDULE.DAYS.WEDNESDAY',
    dayIndex: 2,
  },
  {
    key: 'thursday',
    label: 'THU',
    labelFullKey: 'SCHEDULE.DAYS.THURSDAY',
    dayIndex: 3,
  },
  {
    key: 'friday',
    label: 'FRI',
    labelFullKey: 'SCHEDULE.DAYS.FRIDAY',
    dayIndex: 4,
  },
  {
    key: 'saturday',
    label: 'SAT',
    labelFullKey: 'SCHEDULE.DAYS.SATURDAY',
    dayIndex: 5,
  },
  {
    key: 'sunday',
    label: 'SUN',
    labelFullKey: 'SCHEDULE.DAYS.SUNDAY',
    dayIndex: 6,
  },
];

const workingHours = computed({
  get: () => props.modelValue,
  set: value => emit('update:modelValue', value),
});

const updateDay = (dayKey, data) => {
  workingHours.value = {
    ...workingHours.value,
    [dayKey]: data,
  };
};

const getDefaultDayConfig = dayKey => ({
  enabled: dayKey !== 'saturday' && dayKey !== 'sunday',
  slots:
    dayKey !== 'saturday' && dayKey !== 'sunday'
      ? [{ start: '09:00', end: '18:00' }]
      : [],
});

const getDayConfig = dayKey => {
  return workingHours.value[dayKey] || getDefaultDayConfig(dayKey);
};

const getHolidayForDay = dayIndex => {
  const today = new Date();
  const year = today.getFullYear();
  const nextYear = year + 1;

  return props.holidays.find(holiday => {
    const holidayDate = new Date(holiday.date);
    if (
      holidayDate.getFullYear() !== year &&
      holidayDate.getFullYear() !== nextYear
    ) {
      return false;
    }
    const dayOfWeek = holidayDate.getDay();
    return (
      dayOfWeek === dayIndex ||
      (dayOfWeek === 0 && dayIndex === 6) ||
      (dayOfWeek === 6 && dayIndex === 5)
    );
  });
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex items-center justify-between">
      <label class="text-sm font-semibold text-n-text-display">
        {{ t('SCHEDULE.SETTINGS.WORKING_HOURS') }}
      </label>
      <div class="flex items-center gap-3 text-xs text-n-slate-8">
        <span class="flex items-center gap-1.5">
          <span class="h-2 w-2 rounded-full bg-n-brand" />
          {{ t('SCHEDULE.SETTINGS.WORKING') }}
        </span>
        <span class="flex items-center gap-1.5">
          <span class="h-2 w-2 rounded-full bg-n-slate-5" />
          {{ t('SCHEDULE.SETTINGS.DAY_OFF') }}
        </span>
      </div>
    </div>
    <div
      class="grid grid-cols-1 gap-2 md:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2"
    >
      <DayScheduleRow
        v-for="day in DAYS"
        :key="day.key"
        :day-label="day.label"
        :day-label-full="t(day.labelFullKey)"
        :day-config="getDayConfig(day.key)"
        :is-holiday="!!getHolidayForDay(day.dayIndex)"
        :holiday-name="getHolidayForDay(day.dayIndex)?.name || ''"
        @update="updateDay(day.key, $event)"
      />
    </div>
  </div>
</template>
