<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store.js';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  to: { type: [Object, String], default: '' },
  label: { type: String, default: '' },
  icon: { type: [String, Object], default: '' },
  expandable: { type: Boolean, default: false },
  isActive: { type: Boolean, default: false },
  hasActiveChild: { type: Boolean, default: false },
  getterKeys: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['toggle']);

const showBadge = useMapGetter(props.getterKeys.badge);
const dynamicCount = useMapGetter(props.getterKeys.count);
const count = computed(() =>
  dynamicCount.value > 99 ? '99+' : dynamicCount.value
);
</script>

<template>
  <component
    :is="to ? 'router-link' : 'div'"
    class="flex items-center gap-3 px-[14px] rounded-pill h-12 min-w-0 transition-all duration-150 backdrop-blur-glass-rail backdrop-saturate-glass border text-[13.5px] font-medium"
    role="button"
    draggable="false"
    :to="to"
    :title="label"
    :class="{
      '!text-n-accent-active-fg bg-n-accent-active border-n-accent-active shadow-pill-active':
        isActive && !hasActiveChild,
      'text-n-text-display bg-n-glass-strong border-n-border-glass shadow-pill-soft':
        hasActiveChild,
      'text-n-text-body bg-n-glass-soft border-n-border-glass-soft shadow-inset-hairline hover:bg-n-glass-strong hover:border-n-border-glass':
        !isActive && !hasActiveChild,
    }"
    @click.stop="emit('toggle')"
  >
    <div
      v-if="icon"
      class="relative flex items-center flex-shrink-0 size-[18px]"
    >
      <Icon :icon="icon" class="size-[18px]" />
      <span
        v-if="showBadge"
        class="size-2 -top-px ltr:-right-px rtl:-left-px bg-n-brand absolute rounded-full border border-n-solid-2"
      />
    </div>
    <div class="flex items-center gap-1.5 flex-grow min-w-0 flex-1">
      <span class="truncate">{{ label }}</span>
      <span
        v-if="dynamicCount && !expandable"
        class="rounded-md capitalize text-xs leading-5 font-medium text-center outline outline-1 px-1 flex-shrink-0"
        :class="{
          '!text-n-accent-active-fg outline-n-accent-active-fg/30': isActive,
          'text-n-text-body outline-n-border-glass-soft': !isActive,
        }"
      >
        {{ count }}
      </span>
    </div>
  </component>
</template>
