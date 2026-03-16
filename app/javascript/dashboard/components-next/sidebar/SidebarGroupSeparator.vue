<script setup>
import Icon from 'next/icon/Icon.vue';

defineProps({
  label: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div
    class="flex items-center gap-2 px-2 py-1.5 rounded-lg h-7 text-n-slate-9 select-none pointer-events-none"
  >
    <Icon v-if="icon" :icon="icon" class="size-4" />
    <span
      class="text-xs font-medium leading-5 flex-grow uppercase tracking-wide"
    >
      {{ label }}
    </span>
  </div>
</template>
