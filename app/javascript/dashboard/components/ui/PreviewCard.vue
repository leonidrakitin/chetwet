<script>
export default {
  props: {
    heading: {
      type: String,
      default: '',
    },
    content: {
      type: String,
      default: '',
    },
    active: {
      type: Boolean,
      default: false,
    },
    src: {
      type: String,
      default: '',
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col min-w-[15rem] max-h-[21.25rem] max-w-[23.75rem] rounded-card border border-solid backdrop-blur-glass-card backdrop-saturate-glass shadow-inset-hairline"
    :class="{
      'bg-n-glass-strong border-n-accent-active shadow-pill-soft': active,
      'bg-n-glass-soft border-n-border-glass-soft': !active,
    }"
  >
    <div
      class="flex justify-between items-center rounded-t-card px-3 w-full h-10 border-b border-solid"
      :class="{
        'bg-n-glass-strong border-n-border-glass': active,
        'bg-n-glass-soft border-n-border-glass-soft': !active,
      }"
    >
      <div
        class="flex items-center p-1 text-sm font-medium text-n-text-display"
      >
        {{ heading }}
      </div>
      <fluent-icon
        v-if="active"
        icon="checkmark-circle"
        type="solid"
        size="24"
        class="text-n-accent-active"
      />
    </div>
    <div
      class="text-n-text-body text-xs leading-[1.4] px-3 pt-3 pb-0 text-start"
    >
      {{ content }}
    </div>
    <div v-if="src" class="p-3">
      <img
        :src="src"
        class="border rounded-md"
        :class="active ? 'border-n-border-glass' : 'border-n-border-glass-soft'"
      />
    </div>
    <slot v-else />
  </div>
</template>
