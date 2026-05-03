<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { format } from 'date-fns';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const holidays = computed({
  get: () => props.modelValue,
  set: value => emit('update:modelValue', value),
});

const newHoliday = ref({ date: '', name: '' });

const addHoliday = () => {
  if (!newHoliday.value.date) return;

  holidays.value = [
    ...holidays.value,
    { date: newHoliday.value.date, name: newHoliday.value.name || '' },
  ];
  newHoliday.value = { date: '', name: '' };
};

const removeHoliday = index => {
  holidays.value = holidays.value.filter((_, i) => i !== index);
};

const formatDate = dateStr => {
  try {
    return format(new Date(dateStr), 'd MMM yyyy');
  } catch {
    return dateStr;
  }
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <label class="text-sm font-medium text-n-text-display">
      {{ t('SCHEDULE.SETTINGS.HOLIDAYS') }}
    </label>

    <div
      v-if="holidays.length"
      class="flex flex-col gap-2 border border-n-border-glass-soft rounded-lg p-3"
    >
      <div
        v-for="(holiday, index) in holidays"
        :key="index"
        class="flex items-center justify-between gap-2 px-2 py-1 bg-n-glass-strong rounded-md"
      >
        <div class="flex items-center gap-2">
          <span class="text-sm font-medium text-n-text-display">
            {{ formatDate(holiday.date) }}
          </span>
          <span v-if="holiday.name" class="text-sm text-n-text-body/60">
            — {{ holiday.name }}
          </span>
        </div>
        <Button icon="i-lucide-x" slate xs @click="removeHoliday(index)" />
      </div>
    </div>

    <div class="flex items-end gap-2 mt-2">
      <div class="flex-1">
        <label class="block text-xs text-n-text-body/60 mb-1">
          {{ t('SCHEDULE.SETTINGS.DATE') }}
        </label>
        <input
          v-model="newHoliday.date"
          type="date"
          class="w-full px-2 py-1.5 text-sm border border-n-border-glass-soft rounded-md bg-n-glass-soft text-n-text-display focus:outline-none focus:ring-2 focus:ring-n-brand"
        />
      </div>
      <div class="flex-1">
        <label class="block text-xs text-n-text-body/60 mb-1">
          {{ t('SCHEDULE.SETTINGS.NAME') }}
        </label>
        <input
          v-model="newHoliday.name"
          type="text"
          :placeholder="t('SCHEDULE.SETTINGS.HOLIDAY_NAME')"
          class="w-full px-2 py-1.5 text-sm border border-n-border-glass-soft rounded-md bg-n-glass-soft text-n-text-display focus:outline-none focus:ring-2 focus:ring-n-brand"
        />
      </div>
      <Button
        :label="t('SCHEDULE.SETTINGS.ADD')"
        :disabled="!newHoliday.date"
        faded
        sm
        @click="addHoliday"
      />
    </div>
  </div>
</template>
