<script setup>
defineProps({
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: 'i-lucide-message-square-off',
  },
});
</script>

<template>
  <div class="flex flex-col items-center justify-center py-16 px-6 text-center">
    <div
      class="size-16 rounded-full bg-n-alpha-2 flex items-center justify-center mb-4"
    >
      <i :class="icon" class="size-8 text-n-text-body/60" />
    </div>
    <h3 class="text-base font-medium text-n-text-display mb-1">
      {{ title }}
    </h3>
    <p v-if="description" class="text-sm text-n-text-body/60 max-w-sm">
      {{ description }}
    </p>
  </div>
</template>
