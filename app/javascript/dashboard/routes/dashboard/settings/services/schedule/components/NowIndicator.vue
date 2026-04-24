<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { SLOT_HEIGHT } from '../composables/useCalendarLayout';

const props = defineProps({
  hoursRange: { type: Object, default: () => ({ start: 9, end: 18 }) },
  slotInterval: { type: Number, default: 30 },
  showDot: { type: Boolean, default: true },
});

const now = ref(new Date());
let timer = null;

const tick = () => {
  now.value = new Date();
};

onMounted(() => {
  timer = window.setInterval(tick, 60 * 1000);
});

onBeforeUnmount(() => {
  if (timer) window.clearInterval(timer);
});

const isVisible = computed(() => {
  const minutes = now.value.getHours() * 60 + now.value.getMinutes();
  const startMin = props.hoursRange.start * 60;
  const endMin = props.hoursRange.end * 60;
  return minutes >= startMin && minutes <= endMin;
});

const topPx = computed(() => {
  const minutes = now.value.getHours() * 60 + now.value.getMinutes();
  const startMin = props.hoursRange.start * 60;
  const pxPerMin = SLOT_HEIGHT / props.slotInterval;
  return (minutes - startMin) * pxPerMin;
});
</script>

<template>
  <div
    v-if="isVisible"
    class="pointer-events-none absolute left-0 right-0 z-30"
    :style="`top: ${topPx}px;`"
  >
    <div class="relative h-0 border-t-2 border-n-ruby-10">
      <span
        v-if="showDot"
        class="absolute -top-[5px] -left-[5px] block size-[10px] rounded-full bg-n-ruby-10 shadow"
      />
    </div>
  </div>
</template>
