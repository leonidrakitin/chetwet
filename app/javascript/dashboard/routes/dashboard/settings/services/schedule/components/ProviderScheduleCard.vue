<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import WorkingHoursEditor from './WorkingHoursEditor.vue';
import BreaksManager from './BreaksManager.vue';
import HolidaysManager from './HolidaysManager.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ProviderScheduleAPI from 'dashboard/api/providerSchedule';
import { TIMEZONES } from '../constants';

const props = defineProps({
  provider: { type: Object, required: true },
  accountSchedule: { type: Object, default: null },
  isUpdating: { type: Boolean, default: false },
});

const emit = defineEmits(['update']);

const { t } = useI18n();

const isExpanded = ref(false);
const isLoadingSchedule = ref(false);
const schedule = ref(null);

const hasOwnSchedule = computed(
  () => schedule.value && !schedule.value.inherit_account_schedule
);

const providerSchedule = computed(
  () => props.provider.provider_schedule || schedule.value
);

const form = ref({
  inherit_account_schedule: true,
  timezone: 'UTC',
  working_hours: {},
  breaks: [],
  holidays: [],
});

const initForm = () => {
  if (providerSchedule.value) {
    form.value = {
      inherit_account_schedule:
        providerSchedule.value.inherit_account_schedule ?? true,
      timezone: providerSchedule.value.timezone || 'UTC',
      working_hours: providerSchedule.value.working_hours || {},
      breaks: providerSchedule.value.breaks || [],
      holidays: providerSchedule.value.holidays || [],
    };
  } else {
    form.value = {
      inherit_account_schedule: true,
      timezone: props.accountSchedule?.timezone || 'UTC',
      working_hours: props.accountSchedule?.working_hours || {},
      breaks: props.accountSchedule?.breaks || [],
      holidays: props.accountSchedule?.holidays || [],
    };
  }
};

const fetchSchedule = async () => {
  if (!props.provider.id) return;

  isLoadingSchedule.value = true;
  try {
    const response = await ProviderScheduleAPI.getSchedule(props.provider.id);
    schedule.value = response.data;
    initForm();
  } catch (error) {
    schedule.value = null;
  } finally {
    isLoadingSchedule.value = false;
  }
};

watch(
  () => props.provider.id,
  () => {
    if (isExpanded.value) {
      fetchSchedule();
    }
  }
);

watch(
  () => props.accountSchedule,
  () => {
    if (form.value.inherit_account_schedule) {
      initForm();
    }
  },
  { deep: true }
);

const toggleExpanded = () => {
  isExpanded.value = !isExpanded.value;
  if (isExpanded.value && !schedule.value) {
    fetchSchedule();
  }
};

const handleInheritToggle = () => {
  form.value.inherit_account_schedule = !form.value.inherit_account_schedule;
  if (form.value.inherit_account_schedule) {
    initForm();
  }
};

const handleSubmit = () => {
  emit('update', {
    providerId: props.provider.id,
    data: form.value,
  });
};
</script>

<template>
  <div class="border border-n-weak rounded-lg overflow-hidden">
    <button
      class="flex items-center justify-between w-full px-4 py-3 text-left hover:bg-n-solid-2 transition-colors"
      @click="toggleExpanded"
    >
      <div class="flex items-center gap-3">
        <div
          class="w-8 h-8 rounded-full bg-n-brand flex items-center justify-center text-white font-medium text-sm"
        >
          {{ provider.name.charAt(0).toUpperCase() }}
        </div>
        <div>
          <div class="font-medium text-n-slate-12">{{ provider.name }}</div>
          <div class="text-xs text-n-slate-10">
            {{
              hasOwnSchedule
                ? t('SCHEDULE.SETTINGS.CUSTOM_SCHEDULE')
                : t('SCHEDULE.SETTINGS.INHERITED_SCHEDULE')
            }}
          </div>
        </div>
      </div>
      <i
        class="i-lucide-chevron-down text-n-slate-10 transition-transform"
        :class="{ 'rotate-180': isExpanded }"
      />
    </button>

    <div v-if="isExpanded" class="px-4 pb-4 border-t border-n-weak">
      <div v-if="isLoadingSchedule" class="py-4 text-center">
        {{ t('SCHEDULE.SETTINGS.LOADING') }}
      </div>

      <div v-else class="flex flex-col gap-4 mt-4">
        <div class="flex items-center gap-2">
          <input
            type="checkbox"
            :checked="!form.inherit_account_schedule"
            class="rounded border-n-weak text-n-brand focus:ring-n-brand"
            @change="handleInheritToggle"
          />
          <label class="text-sm text-n-slate-12">
            {{ t('SCHEDULE.SETTINGS.USE_CUSTOM_SCHEDULE') }}
          </label>
        </div>

        <template v-if="!form.inherit_account_schedule">
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
          </div>

          <WorkingHoursEditor v-model="form.working_hours" />
          <BreaksManager v-model="form.breaks" />
          <HolidaysManager v-model="form.holidays" />
        </template>

        <div class="flex justify-end gap-2">
          <Button
            :label="t('SCHEDULE.SETTINGS.SAVE')"
            :is-loading="isUpdating"
            @click="handleSubmit"
          />
        </div>
      </div>
    </div>
  </div>
</template>
