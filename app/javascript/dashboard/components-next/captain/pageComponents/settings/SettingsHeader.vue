<script setup>
defineProps({
  heading: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <header class="flex flex-col items-start gap-2">
    <h2 class="text-n-text-display text-base font-medium">{{ heading }}</h2>
    <p class="text-n-text-body text-sm">{{ description }}</p>
  </header>
</template>
