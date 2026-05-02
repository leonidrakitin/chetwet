<script setup>
import EmojiOrIcon from 'shared/components/EmojiOrIcon.vue';
import { defineEmits } from 'vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  compact: {
    type: Boolean,
    default: false,
  },
  icon: {
    type: String,
    default: '',
  },
  emoji: {
    type: String,
    default: '',
  },
  isOpen: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['toggle']);

const onToggle = () => {
  emit('toggle');
};
</script>

<template>
  <div
    class="text-sm bg-n-glass-soft border border-n-border-glass-soft rounded-chip overflow-hidden"
  >
    <button
      class="flex items-center gap-2 select-none w-full m-0 cursor-grab justify-between py-2.5 px-3 drag-handle"
      @click.stop="onToggle"
    >
      <div class="flex items-center gap-1.5 min-w-0">
        <EmojiOrIcon
          v-if="icon || emoji"
          class="inline-block w-5"
          :icon="icon"
          :emoji="emoji"
        />
        <h5
          class="text-n-text-display text-xs font-semibold tracking-tight mb-0 py-0 pr-1 pl-0 truncate"
        >
          {{ title }}
        </h5>
      </div>
      <div class="flex flex-row items-center gap-1">
        <slot name="button" />
        <span
          class="i-lucide-chevron-down size-3 text-n-text-muted transition-transform"
          :class="{ 'rotate-180': isOpen }"
        />
      </div>
    </button>
    <div
      v-if="isOpen"
      class="border-t border-n-border-hairline"
      :class="compact ? 'p-0' : 'px-3 py-3'"
    >
      <slot />
    </div>
  </div>
</template>
