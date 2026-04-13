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
    <label class="text-sm font-medium text-n-slate-12">
      {{ t('SCHEDULE.SETTINGS.HOLIDAYS') }}
    </label>

    <div
      v-if="holidays.length"
      class="flex flex-col gap-2 border border-n-weak rounded-lg p-3"
    >
      <div
        v-for="(holiday, index) in holidays"
        :key="index"
        class="flex items-center justify-between gap-2 px-2 py-1 bg-n-solid-2 rounded-md"
      >
        <div class="flex items-center gap-2">
          <span class="text-sm font-medium text-n-slate-12">
            {{ formatDate(holiday.date) }}
          </span>
          <span v-if="holiday.name" class="text-sm text-n-slate-10">
            — {{ holiday.name }}
          </span>
        </div>
        <Button icon="i-lucide-x" slate xs @click="removeHoliday(index)" />
      </div>
    </div>

    <div class="flex items-end gap-2 mt-2">
      <div class="flex-1">
        <label class="block text-xs text-n-slate-10 mb-1">
          {{ t('SCHEDULE.SETTINGS.DATE') }}
        </label>
        <input
          v-model="newHoliday.date"
          type="date"
          class="w-full px-2 py-1.5 text-sm border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
        />
      </div>
      <div class="flex-1">
        <label class="block text-xs text-n-slate-10 mb-1">
          {{ t('SCHEDULE.SETTINGS.NAME') }}
        </label>
        <input
          v-model="newHoliday.name"
          type="text"
          :placeholder="t('SCHEDULE.SETTINGS.HOLIDAY_NAME')"
          class="w-full px-2 py-1.5 text-sm border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
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
