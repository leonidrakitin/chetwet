<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  dayLabel: { type: String, required: true },
  dayLabelFull: { type: String, required: true },
  dayConfig: { type: Object, default: () => ({ enabled: false, slots: [] }) },
  isHoliday: { type: Boolean, default: false },
  holidayName: { type: String, default: '' },
});

const emit = defineEmits(['update']);

const { t } = useI18n();

const isEnabled = computed(() => props.dayConfig.enabled);
const slots = computed(() => props.dayConfig.slots || []);
const hasMultipleSlots = computed(() => slots.value.length > 1);

const isSlotInvalid = slot => {
  if (!slot.start || !slot.end) return false;
  return slot.start >= slot.end;
};

const hasInvalidSlots = computed(() => {
  return slots.value.some(slot => isSlotInvalid(slot));
});

const toggleEnabled = () => {
  emit('update', {
    ...props.dayConfig,
    enabled: !isEnabled.value,
    slots: !isEnabled.value ? [{ start: '09:00', end: '18:00' }] : [],
  });
};

const addSlot = () => {
  const lastSlot = slots.value[slots.value.length - 1];
  const newStart = lastSlot?.end || '09:00';
  const [h, m] = newStart.split(':').map(Number);
  const endHour = (h + 2) % 24;
  const newEnd = `${String(endHour).padStart(2, '0')}:${String(m).padStart(2, '0')}`;

  emit('update', {
    ...props.dayConfig,
    slots: [...slots.value, { start: newStart, end: newEnd }],
  });
};

const removeSlot = index => {
  const newSlots = slots.value.filter((_, i) => i !== index);
  if (newSlots.length === 0) {
    emit('update', { ...props.dayConfig, enabled: false, slots: [] });
  } else {
    emit('update', { ...props.dayConfig, slots: newSlots });
  }
};

const updateSlot = (index, field, value) => {
  const newSlots = slots.value.map((slot, i) =>
    i === index ? { ...slot, [field]: value } : slot
  );
  emit('update', { ...props.dayConfig, slots: newSlots });
};

const makeDayOff = () => {
  emit('update', { ...props.dayConfig, enabled: false, slots: [] });
};
</script>

<template>
  <div
    class="group relative overflow-hidden rounded-xl border transition-all duration-200"
    :class="
      isEnabled
        ? 'border-n-brand/30 bg-gradient-to-br from-n-brand/5 to-n-brand/10 shadow-sm hover:shadow-md hover:border-n-brand/50'
        : 'border-n-border-glass-soft/50 bg-n-glass-strong/50 hover:bg-n-glass-strong'
    "
  >
    <div class="flex items-stretch">
      <button
        class="flex w-14 flex-col items-center justify-center gap-1 py-3 transition-all duration-200"
        :class="isEnabled ? 'bg-n-brand/10' : 'hover:bg-n-solid-3'"
        @click="toggleEnabled"
      >
        <div
          class="flex h-6 w-6 items-center justify-center rounded-full transition-all duration-200"
          :class="
            isEnabled
              ? 'bg-n-brand text-n-brand-inverted'
              : 'bg-n-slate-5 text-n-slate-8'
          "
        >
          <svg
            v-if="isEnabled"
            class="h-3.5 w-3.5"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="3"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M5 13l4 4L19 7"
            />
          </svg>
          <span v-else class="text-[10px] font-bold">{{ dayLabel }}</span>
        </div>
        <span
          class="text-[9px] font-medium uppercase tracking-wide"
          :class="isEnabled ? 'text-n-brand' : 'text-n-slate-8'"
        >
          {{ dayLabel }}
        </span>
      </button>

      <div class="flex flex-1 flex-col py-2 pl-3 pr-4">
        <div class="mb-1 flex items-center justify-between">
          <span class="text-sm font-medium text-n-text-display">
            {{ dayLabelFull }}
          </span>
          <div class="flex items-center gap-2">
            <span
              v-if="isHoliday && !isEnabled"
              class="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-medium text-amber-800"
            >
              <svg
                class="h-3 w-3"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                />
              </svg>
              {{ holidayName || t('SCHEDULE.SETTINGS.HOLIDAY') }}
            </span>
            <span
              v-if="!isEnabled && !isHoliday"
              class="text-[10px] font-medium uppercase tracking-wider text-n-slate-8"
            >
              {{ t('SCHEDULE.SETTINGS.DAY_OFF') }}
            </span>
          </div>
        </div>

        <div v-if="isEnabled" class="flex flex-col gap-1.5">
          <div
            v-for="(slot, index) in slots"
            :key="index"
            class="flex items-center gap-2"
          >
            <div
              class="flex flex-1 items-center gap-1 rounded-lg border bg-n-glass-soft px-2 py-1.5 transition-all duration-150"
              :class="
                isSlotInvalid(slot)
                  ? 'border-red-400/50 bg-red-50/50'
                  : 'border-n-border-glass-soft/50 hover:border-n-border-glass-soft'
              "
            >
              <svg
                class="h-3.5 w-3.5 flex-shrink-0 text-n-slate-8"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              <input
                type="time"
                :value="slot.start"
                class="w-full flex-1 bg-transparent text-sm font-medium text-n-text-display outline-none"
                @change="updateSlot(index, 'start', $event.target.value)"
              />
              <span class="text-n-slate-6">
                <span class="i-lucide-arrow-right h-3.5 w-3.5" />
              </span>
              <input
                type="time"
                :value="slot.end"
                class="w-full flex-1 bg-transparent text-sm font-medium text-n-text-display outline-none"
                @change="updateSlot(index, 'end', $event.target.value)"
              />
            </div>

            <button
              class="flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-lg border border-transparent text-n-slate-8 opacity-0 transition-all duration-150 hover:border-n-border-glass-soft hover:bg-n-solid-3 group-hover:opacity-100"
              :class="{ 'opacity-100': hasMultipleSlots }"
              :title="t('SCHEDULE.SETTINGS.REMOVE_SLOT')"
              @click="removeSlot(index)"
            >
              <svg
                class="h-3.5 w-3.5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>

          <div class="mt-1 flex items-center gap-2">
            <button
              class="inline-flex items-center gap-1.5 rounded-lg border border-dashed border-n-border-glass-soft px-2.5 py-1 text-xs font-medium text-n-text-body/60 transition-all duration-150 hover:border-n-brand hover:text-n-brand"
              @click="addSlot"
            >
              <svg
                class="h-3 w-3"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2.5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 4v16m8-8H4"
                />
              </svg>
              {{ t('SCHEDULE.SETTINGS.ADD_SLOT') }}
            </button>

            <button
              v-if="slots.length > 0"
              class="inline-flex items-center gap-1.5 rounded-lg px-2.5 py-1 text-xs font-medium text-n-slate-8 transition-all duration-150 hover:bg-n-slate-4"
              @click="makeDayOff"
            >
              <svg
                class="h-3 w-3"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"
                />
              </svg>
              {{ t('SCHEDULE.SETTINGS.MAKE_DAY_OFF') }}
            </button>
          </div>

          <div
            v-if="hasInvalidSlots"
            class="mt-1 flex items-center gap-1.5 text-xs text-red-600"
          >
            <svg
              class="h-3.5 w-3.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
              />
            </svg>
            {{ t('SCHEDULE.SETTINGS.INVALID_TIME_RANGE') }}
          </div>
        </div>

        <div v-else class="flex items-center gap-2">
          <button
            class="inline-flex items-center gap-1.5 rounded-lg border border-dashed border-n-border-glass-soft px-3 py-1.5 text-xs font-medium text-n-slate-8 transition-all duration-150 hover:border-n-brand hover:text-n-brand"
            @click="toggleEnabled"
          >
            <svg
              class="h-3 w-3"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2.5"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 4v16m8-8H4"
              />
            </svg>
            {{ t('SCHEDULE.SETTINGS.MAKE_WORKING_DAY') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
