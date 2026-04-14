<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import WorkingHoursEditor from '../components/WorkingHoursEditor.vue';
import BreaksManager from '../components/BreaksManager.vue';
import HolidaysManager from '../components/HolidaysManager.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { TIMEZONES, SLOT_INTERVALS } from '../constants';

const props = defineProps({
  schedule: { type: Object, default: null },
  isUpdating: { type: Boolean, default: false },
});

const emit = defineEmits(['update']);

const { t } = useI18n();

const form = ref({
  timezone: 'UTC',
  slot_interval_minutes: 30,
  working_hours: {},
  breaks: [],
  holidays: [],
});

watch(
  () => props.schedule,
  newSchedule => {
    if (newSchedule) {
      form.value = {
        timezone: newSchedule.timezone || 'UTC',
        slot_interval_minutes: newSchedule.slot_interval_minutes || 30,
        working_hours: newSchedule.working_hours || {},
        breaks: newSchedule.breaks || [],
        holidays: newSchedule.holidays || [],
      };
    }
  },
  { immediate: true }
);

const handleSubmit = () => {
  emit('update', form.value);
};
</script>

<template>
  <div
    class="flex flex-col gap-6 p-6 bg-n-solid-1 rounded-lg border border-n-weak"
  >
    <div class="grid grid-cols-2 gap-4">
      <div>
        <label class="block text-sm font-medium text-n-slate-12 mb-1">
          {{ t('SCHEDULE.SETTINGS.TIMEZONE') }}
        </label>
        <select
          v-model="form.timezone"
          class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
        >
          <option v-for="tz in TIMEZONES" :key="tz" :value="tz">
            {{ tz }}
          </option>
        </select>
      </div>

      <div>
        <label class="block text-sm font-medium text-n-slate-12 mb-1">
          {{ t('SCHEDULE.SETTINGS.SLOT_INTERVAL') }}
        </label>
        <select
          v-model="form.slot_interval_minutes"
          class="w-full px-3 py-2 border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
        >
          <option
            v-for="interval in SLOT_INTERVALS"
            :key="interval"
            :value="interval"
          >
            {{ `${interval} ${t('SCHEDULE.SETTINGS.MINUTES')}` }}
          </option>
        </select>
      </div>
    </div>

    <WorkingHoursEditor v-model="form.working_hours" />

    <BreaksManager v-model="form.breaks" />

    <HolidaysManager v-model="form.holidays" />

    <div class="flex justify-end">
      <Button
        :label="t('SCHEDULE.SETTINGS.SAVE')"
        :is-loading="isUpdating"
        @click="handleSubmit"
      />
    </div>
  </div>
</template>
