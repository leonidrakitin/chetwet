<script setup>
defineProps({
  layout: {
    type: String,
    default: 'col',
  },
  selectable: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['click']);

const handleClick = () => {
  emit('click');
};
</script>

<template>
  <div
    class="flex flex-col w-full border border-n-border-glass-soft group/cardLayout rounded-card bg-n-glass-strong backdrop-blur-glass-card backdrop-saturate-glass shadow-glass-soft"
  >
    <div
      class="flex w-full gap-3 py-5"
      :class="[
        layout === 'col' ? 'flex-col' : 'flex-row justify-between items-center',
        selectable ? 'px-10 py-6' : 'px-6',
      ]"
      @click="handleClick"
    >
      <slot />
    </div>

    <slot name="after" />
  </div>
</template>
