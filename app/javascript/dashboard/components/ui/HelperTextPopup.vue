<script setup>
defineProps({
  message: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div class="relative group w-[inherit] whitespace-normal z-20">
    <fluent-icon
      icon="info"
      size="14"
      class="mt-0.5 text-n-text-body absolute"
    />
    <div
      class="bg-n-glass-pane backdrop-blur-glass-card backdrop-saturate-glass w-fit ltr:left-4 rtl:right-4 top-0 border p-2.5 group-hover:flex items-center hidden absolute border-n-border-glass rounded-card shadow-glass-soft"
    >
      <p class="text-n-text-display mb-0 text-xs">
        {{ message }}
      </p>
    </div>
  </div>
</template>
