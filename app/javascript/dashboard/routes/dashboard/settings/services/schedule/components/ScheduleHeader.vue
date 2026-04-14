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
</script>

<template>
  <div
    class="flex items-center justify-between px-4 py-3 border-b border-n-weak"
  >
    <div class="flex items-center gap-3">
      <div class="flex items-center gap-1">
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
      <span class="text-lg font-semibold text-n-slate-12">
        {{ formattedDate }}
      </span>
    </div>

    <div class="flex items-center gap-4">
      <div v-if="viewMode === 'week'" class="flex items-center gap-2">
        <span class="text-sm text-n-slate-11">
          {{ t('SCHEDULE.PROVIDER') }}:
        </span>
        <select
          :value="selectedProviderId"
          class="px-3 py-1.5 text-sm border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
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

      <div class="flex rounded-lg border border-n-weak overflow-hidden">
        <button
          class="px-3 py-1.5 text-sm font-medium transition-colors"
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
          class="px-3 py-1.5 text-sm font-medium transition-colors border-l border-n-weak"
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
          class="px-3 py-1.5 text-sm font-medium transition-colors border-l border-n-weak"
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
          class="px-3 py-1.5 text-sm font-medium transition-colors border-l border-n-weak"
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

      <Button
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
</template>
