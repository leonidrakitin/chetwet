<script setup>
defineProps({
  buttonText: {
    type: String,
    default: '',
  },
  isActive: {
    type: Boolean,
    default: false,
  },
  icon: {
    type: String,
    default: '',
  },
  iconColor: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <button
    class="relative inline-flex items-center justify-start w-full px-3 py-2 mx-1 my-0.5 border-0 rounded-pill h-10 hover:enabled:bg-n-glass-soft transition-colors duration-150"
  >
    <div class="inline-flex items-center gap-3 overflow-hidden">
      <fluent-icon
        v-if="icon"
        :icon="icon"
        size="18"
        :style="{ color: iconColor }"
      />
      <span class="text-sm font-medium truncate text-n-text-display">
        {{ buttonText }}
      </span>
      <fluent-icon
        v-if="isActive"
        icon="checkmark"
        size="18"
        class="flex-shrink-0 text-n-text-display"
      />
    </div>
    <slot name="dropdown" />
  </button>
</template>
