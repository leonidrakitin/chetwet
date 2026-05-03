<script setup>
defineProps({
  title: {
    type: String,
    required: true,
  },
  buttons: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['click', 'close']);

const handleButtonClick = button => {
  emit('click', button.key);
};
</script>

<template>
  <div
    class="flex items-center justify-between px-4 py-3.5 border-b border-n-border-hairline bg-transparent"
  >
    <div class="flex items-center justify-between gap-2 flex-1">
      <span
        class="font-interDisplay text-sm font-bold tracking-tight text-n-text-display"
      >
        {{ title }}
      </span>
      <div class="flex items-center gap-1">
        <button
          v-for="button in buttons"
          :key="button.key"
          v-tooltip="button.tooltip"
          type="button"
          class="size-7 rounded-[10px] bg-n-glass-soft text-n-text-body hover:bg-n-alpha-2 inline-flex items-center justify-center transition-colors"
          @click="handleButtonClick(button)"
        >
          <span class="size-3.5" :class="[button.icon]" />
        </button>
        <button
          v-tooltip="$t('GENERAL.CLOSE')"
          type="button"
          class="size-7 rounded-[10px] bg-n-glass-soft text-n-text-body hover:bg-n-alpha-2 inline-flex items-center justify-center transition-colors"
          @click="$emit('close')"
        >
          <span class="i-lucide-x size-3.5" />
        </button>
      </div>
    </div>
  </div>
</template>
