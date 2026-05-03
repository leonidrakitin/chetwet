<script setup>
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';

defineProps({
  header: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  compact: {
    type: Boolean,
    default: false,
  },
  hideToggle: {
    type: Boolean,
    default: false,
  },
});

const modelValue = defineModel({ type: Boolean, default: false });
</script>

<template>
  <div
    class="flex flex-col items-start border border-n-border-glass-soft rounded-card bg-n-glass-soft backdrop-blur-glass-card backdrop-saturate-glass shadow-inset-hairline [interpolate-size:allow-keywords]"
  >
    <div class="flex flex-col gap-1 items-start w-full px-4 py-3">
      <div class="flex items-center gap-3 w-full justify-between">
        <span class="text-heading-3 text-n-text-display">
          {{ header }}
        </span>
        <div v-if="hideToggle" class="size-2" />
        <ToggleSwitch v-else v-model="modelValue" />
      </div>
      <span v-if="description" class="text-body-main text-n-text-body">
        {{ description }}
      </span>
    </div>
    <div
      v-if="$slots.editor"
      class="w-full border-t border-n-border-glass-soft"
      :class="{ 'p-0': compact, 'px-4 pb-4 pt-2': !compact }"
    >
      <slot name="editor" />
    </div>
  </div>
</template>
