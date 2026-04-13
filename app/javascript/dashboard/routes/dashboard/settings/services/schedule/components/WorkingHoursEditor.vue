<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import DayScheduleRow from './DayScheduleRow.vue';

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const DAYS = [
  { key: 'monday', label: 'MON' },
  { key: 'tuesday', label: 'TUE' },
  { key: 'wednesday', label: 'WED' },
  { key: 'thursday', label: 'THU' },
  { key: 'friday', label: 'FRI' },
  { key: 'saturday', label: 'SAT' },
  { key: 'sunday', label: 'SUN' },
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
</script>

<template>
  <div class="flex flex-col gap-2">
    <label class="text-sm font-medium text-n-slate-12 mb-2">
      {{ t('SCHEDULE.SETTINGS.WORKING_HOURS') }}
    </label>
    <div
      class="flex flex-col gap-1 border border-n-weak rounded-lg overflow-hidden"
    >
      <DayScheduleRow
        v-for="day in DAYS"
        :key="day.key"
        :day-label="day.label"
        :day-config="getDayConfig(day.key)"
        @update="updateDay(day.key, $event)"
      />
    </div>
  </div>
</template>
