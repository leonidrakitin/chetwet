<script setup>
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import {
  format,
  addDays,
  addMonths,
  subDays,
  subMonths,
  startOfWeek,
  endOfWeek,
  isToday,
} from 'date-fns';
import { ru } from 'date-fns/locale';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  currentDate: {
    type: Date,
    required: true,
  },
  viewMode: {
    type: String,
    default: 'day',
    validator: value => ['day', 'week', 'month', 'agenda'].includes(value),
  },
  selectedProviderId: {
    type: [Number, String],
    default: null,
  },
  providers: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits([
  'update:currentDate',
  'update:viewMode',
  'update:selectedProviderId',
  'addBooking',
]);

const { t } = useI18n();
const router = useRouter();

const formattedDate = computed(() => {
  if (props.viewMode === 'day') {
    return format(props.currentDate, 'd MMMM yyyy', { locale: ru });
  }
  if (props.viewMode === 'month') {
    return format(props.currentDate, 'LLLL yyyy', { locale: ru });
  }
  if (props.viewMode === 'agenda') {
    return t('SCHEDULE.AGENDA');
  }
  const start = startOfWeek(props.currentDate, { weekStartsOn: 1 });
  const end = endOfWeek(props.currentDate, { weekStartsOn: 1 });
  return `${format(start, 'd MMM', { locale: ru })} - ${format(end, 'd MMM yyyy', { locale: ru })}`;
});

const goToToday = () => {
  emit('update:currentDate', new Date());
};

const goToPrev = () => {
  if (props.viewMode === 'agenda') return;
  if (props.viewMode === 'month') {
    emit('update:currentDate', subMonths(props.currentDate, 1));
    return;
  }
  const delta = props.viewMode === 'day' ? 1 : 7;
  emit('update:currentDate', subDays(props.currentDate, delta));
};

const goToNext = () => {
  if (props.viewMode === 'agenda') return;
  if (props.viewMode === 'month') {
    emit('update:currentDate', addMonths(props.currentDate, 1));
    return;
  }
  const delta = props.viewMode === 'day' ? 1 : 7;
  emit('update:currentDate', addDays(props.currentDate, delta));
};

const setViewMode = mode => {
  emit('update:viewMode', mode);
};

const goToSettings = () => {
  router.push({ name: 'services_schedule_settings' });
};

const isCurrentToday = computed(() => {
  if (props.viewMode === 'day') {
    return isToday(props.currentDate);
  }
  return false;
});

const providerFilterLabel = computed(() => `${t('SCHEDULE.PROVIDER')}:`);
</script>

<template>
  <div
    class="flex flex-col gap-3 px-2 py-3 sm:px-4 sm:py-3 border-b border-n-weak"
  >
    <div
      class="flex flex-col gap-3 min-w-0 sm:flex-row sm:items-center sm:justify-between sm:gap-4"
    >
      <div class="flex flex-wrap items-center gap-2 min-w-0">
        <div class="flex items-center gap-1 shrink-0">
          <Button
            icon="i-lucide-chevron-left"
            slate
            sm
            :disabled="viewMode === 'agenda'"
            @click="goToPrev"
          />
          <Button
            v-if="viewMode !== 'agenda'"
            :label="t('SCHEDULE.TODAY')"
            :variant="isCurrentToday ? 'solid' : 'faded'"
            :color="isCurrentToday ? 'blue' : 'slate'"
            sm
            @click="goToToday"
          />
          <Button
            icon="i-lucide-chevron-right"
            slate
            sm
            :disabled="viewMode === 'agenda'"
            @click="goToNext"
          />
        </div>
        <span
          class="text-base sm:text-lg font-semibold text-n-slate-12 truncate min-w-0 flex-1 sm:flex-none"
        >
          {{ formattedDate }}
        </span>
      </div>

      <div
        class="flex flex-col gap-2 w-full sm:w-auto sm:flex-row sm:items-center sm:justify-end sm:flex-wrap sm:gap-3"
      >
        <div
          v-if="viewMode === 'week'"
          class="flex flex-col gap-1 w-full sm:w-auto sm:flex-row sm:items-center sm:gap-2 min-w-0"
        >
          <span class="text-xs sm:text-sm text-n-slate-11 shrink-0">
            {{ providerFilterLabel }}
          </span>
          <select
            :value="selectedProviderId"
            class="w-full sm:w-auto min-w-0 max-w-full px-3 py-2 text-sm border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
            @change="
              $emit('update:selectedProviderId', Number($event.target.value))
            "
          >
            <option
              v-for="provider in providers"
              :key="provider.id"
              :value="provider.id"
            >
              {{ provider.name }}
            </option>
          </select>
        </div>

        <div
          class="grid grid-cols-2 sm:inline-flex sm:rounded-lg sm:border sm:border-n-weak sm:overflow-hidden gap-1 sm:gap-0 w-full sm:w-auto"
        >
          <button
            type="button"
            class="px-2.5 py-2 sm:py-1.5 text-xs sm:text-sm font-medium transition-colors rounded-md sm:rounded-none border border-n-weak sm:border-0"
            :class="[
              viewMode === 'day'
                ? 'bg-n-brand text-white'
                : 'bg-n-solid-1 text-n-slate-11 hover:bg-n-solid-2',
            ]"
            @click="setViewMode('day')"
          >
            {{ t('SCHEDULE.DAY') }}
          </button>
          <button
            type="button"
            class="px-2.5 py-2 sm:py-1.5 text-xs sm:text-sm font-medium transition-colors rounded-md sm:rounded-none border border-n-weak sm:border-0 sm:border-l"
            :class="[
              viewMode === 'week'
                ? 'bg-n-brand text-white'
                : 'bg-n-solid-1 text-n-slate-11 hover:bg-n-solid-2',
            ]"
            @click="setViewMode('week')"
          >
            {{ t('SCHEDULE.WEEK') }}
          </button>
          <button
            type="button"
            class="px-2.5 py-2 sm:py-1.5 text-xs sm:text-sm font-medium transition-colors rounded-md sm:rounded-none border border-n-weak sm:border-0 sm:border-l"
            :class="[
              viewMode === 'month'
                ? 'bg-n-brand text-white'
                : 'bg-n-solid-1 text-n-slate-11 hover:bg-n-solid-2',
            ]"
            @click="setViewMode('month')"
          >
            {{ t('SCHEDULE.MONTH') }}
          </button>
          <button
            type="button"
            class="px-2.5 py-2 sm:py-1.5 text-xs sm:text-sm font-medium transition-colors rounded-md sm:rounded-none border border-n-weak sm:border-0 sm:border-l"
            :class="[
              viewMode === 'agenda'
                ? 'bg-n-brand text-white'
                : 'bg-n-solid-1 text-n-slate-11 hover:bg-n-solid-2',
            ]"
            @click="setViewMode('agenda')"
          >
            {{ t('SCHEDULE.AGENDA') }}
          </button>
        </div>

        <div
          class="flex items-center gap-2 w-full sm:w-auto justify-stretch sm:justify-end"
        >
          <Button
            class="flex-1 sm:flex-initial"
            icon="i-lucide-plus"
            :label="t('SCHEDULE.MODAL.ADD_BUTTON')"
            sm
            @click="emit('addBooking')"
          />

          <Button
            icon="i-lucide-settings"
            :tooltip="t('SCHEDULE.SETTINGS.HEADER')"
            slate
            sm
            @click="goToSettings"
          />
        </div>
      </div>
    </div>
  </div>
</template>
