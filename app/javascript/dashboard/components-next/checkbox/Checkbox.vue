<script setup>
defineProps({
  indeterminate: {
    type: Boolean,
    default: false,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['change']);

const modelValue = defineModel('modelValue', {
  type: Boolean,
  default: false,
});

const handleChange = event => {
  modelValue.value = event.target.checked;
  emit('change', event);
};
</script>

<template>
  <div class="relative w-4 h-4">
    <input
      :checked="modelValue"
      :indeterminate="indeterminate"
      type="checkbox"
      :disabled="disabled"
      class="peer absolute inset-0 z-10 h-4 w-4 disabled:opacity-50 appearance-none rounded border border-n-border-glass ring-transparent transition-all duration-200 checked:border-n-accent-active checked:bg-n-accent-active dark:border-n-border-glass dark:checked:border-n-accent-active indeterminate:border-n-accent-active indeterminate:bg-n-accent-active hover:enabled:bg-n-glass-strong cursor-pointer"
      @change="handleChange"
    />
    <!-- Checkmark SVG -->
    <svg
      viewBox="0 0 14 14"
      fill="none"
      class="pointer-events-none absolute w-3.5 h-3.5 z-20 stroke-n-accent-active-fg opacity-0 peer-checked:opacity-100 transition-opacity duration-200 left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
    >
      <path
        d="M3 8L6 11L11 3.5"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    <!-- Minus/Indeterminate SVG -->
    <svg
      viewBox="0 0 14 14"
      fill="none"
      class="pointer-events-none absolute w-3.5 h-3.5 z-20 stroke-white opacity-0 peer-indeterminate:opacity-100 transition-opacity duration-200 left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
    >
      <path
        d="M3 7L11 7"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
  </div>
</template>
