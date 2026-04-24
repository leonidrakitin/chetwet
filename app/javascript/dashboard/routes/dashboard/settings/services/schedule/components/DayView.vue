<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useScroll, useResizeObserver } from '@vueuse/core';
import TimeAxis from './TimeAxis.vue';
import ProviderColumn from './ProviderColumn.vue';
import HiddenProvidersIndicator from './HiddenProvidersIndicator.vue';
import { useTimeSlots } from '../composables/useTimeSlots';

const props = defineProps({
  date: { type: Date, required: true },
  providers: { type: Array, default: () => [] },
  bookings: { type: Array, default: () => [] },
  schedule: { type: Object, default: null },
});

const emit = defineEmits([
  'bookingClick',
  'slotClick',
  'bookingCreate',
  'bookingMove',
  'bookingResize',
]);

const {
  slotInterval,
  hoursRange,
  workingHoursForDay,
  isEnabledDay,
  isHoliday,
} = useTimeSlots(
  computed(() => props.schedule),
  computed(() => props.date)
);

const dayWorkingHours = computed(() => workingHoursForDay.value);

const providerBookings = computed(() => {
  const grouped = {};
  props.providers.forEach(provider => {
    grouped[provider.id] = props.bookings.filter(
      booking => booking.service_provider?.id === provider.id
    );
  });
  return grouped;
});

const handleSlotClick = ({ providerId, time }) => {
  emit('slotClick', { providerId, date: props.date, time });
};

const handleBookingCreate = ({ providerId, startTime, durationMinutes }) => {
  emit('bookingCreate', {
    providerId,
    date: props.date,
    startTime,
    durationMinutes,
  });
};

const handleBookingMove = ({ bookingId, newProviderId, newTime }) => {
  emit('bookingMove', { bookingId, newProviderId, newScheduledAt: newTime });
};

const scrollRef = ref(null);
const colRefs = ref([]);
const containerWidth = ref(0);

const { x: scrollLeft } = useScroll(scrollRef);

const TIME_AXIS_WIDTH_XS = 48;
const TIME_AXIS_WIDTH_SM = 64;

const isSmallScreen = ref(window.innerWidth < 640);

const timeAxisWidth = computed(() =>
  isSmallScreen.value ? TIME_AXIS_WIDTH_XS : TIME_AXIS_WIDTH_SM
);

const setColRef = (el, index) => {
  if (el) {
    colRefs.value[index] = el;
  }
};

const updateScreenSize = () => {
  isSmallScreen.value = window.innerWidth < 640;
};

const hiddenProviders = computed(() => {
  if (!scrollRef.value || colRefs.value.length === 0) return [];

  const currentScrollLeft = scrollLeft.value;
  const visibleWidth = containerWidth.value;

  const hidden = [];
  const safetyPx = 20;

  colRefs.value.forEach((colEl, index) => {
    if (!colEl) return;
    const colLeft = colEl.offsetLeft;
    const colRight = colLeft + colEl.offsetWidth;

    const isVisible =
      colRight > currentScrollLeft + timeAxisWidth.value &&
      colLeft < currentScrollLeft + visibleWidth - safetyPx;

    if (!isVisible && colLeft > currentScrollLeft + visibleWidth - safetyPx) {
      hidden.push(props.providers[index]);
    }
  });

  return hidden;
});

const scrollToProvider = providerId => {
  const index = props.providers.findIndex(p => p.id === providerId);
  if (index === -1 || !colRefs.value[index]) return;

  const colEl = colRefs.value[index];
  const targetLeft = colEl.offsetLeft - timeAxisWidth.value;

  scrollRef.value.scrollTo({
    left: Math.max(0, targetLeft),
    behavior: 'smooth',
  });
};

useResizeObserver(scrollRef, entries => {
  const entry = entries[0];
  if (entry) {
    containerWidth.value = entry.contentRect.width;
  }
});

onMounted(() => {
  window.addEventListener('resize', updateScreenSize);
  updateScreenSize();
});

onBeforeUnmount(() => {
  window.removeEventListener('resize', updateScreenSize);
});
</script>

<template>
  <div class="relative w-full min-w-0">
    <div
      ref="scrollRef"
      class="flex overflow-x-auto overflow-y-visible [scrollbar-gutter:stable]"
    >
      <TimeAxis :hours-range="hoursRange" :slot-interval="slotInterval" />

      <div
        v-if="!isEnabledDay || isHoliday"
        class="flex-1 flex items-center justify-center min-h-[200px]"
      >
        <div class="text-center text-n-slate-11">
          <p class="text-lg font-medium">
            {{
              isHoliday
                ? $t('SCHEDULE.HOLIDAY')
                : $t('SCHEDULE.NOT_WORKING_DAY')
            }}
          </p>
        </div>
      </div>

      <template v-else>
        <ProviderColumn
          v-for="(provider, index) in providers"
          :key="provider.id"
          :ref="el => setColRef(el, index)"
          :provider="provider"
          :bookings="providerBookings[provider.id] || []"
          :hours-range="hoursRange"
          :slot-interval="slotInterval"
          :date="date"
          :working-hours="dayWorkingHours"
          @booking-click="$emit('bookingClick', $event)"
          @slot-click="handleSlotClick"
          @booking-create="handleBookingCreate"
          @booking-dragend="handleBookingMove"
          @booking-resize="$emit('bookingResize', $event)"
        />
      </template>
    </div>

    <HiddenProvidersIndicator
      v-if="hiddenProviders.length"
      :providers="hiddenProviders"
      @select="scrollToProvider"
    />
  </div>
</template>
