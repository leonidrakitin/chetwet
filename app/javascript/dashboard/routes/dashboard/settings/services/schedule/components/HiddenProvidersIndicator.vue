<script setup>
import { ref } from 'vue';
import { vOnClickOutside } from '@vueuse/components';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  providers: { type: Array, default: () => [] },
});

const emit = defineEmits(['select']);

const isOpen = ref(false);

const toggle = () => {
  isOpen.value = !isOpen.value;
};

const close = () => {
  isOpen.value = false;
};

const pick = provider => {
  emit('select', provider.id);
  close();
};
</script>

<template>
  <div
    v-if="providers.length"
    v-on-click-outside="close"
    class="absolute top-14 right-2 z-10"
  >
    <button
      class="flex items-center gap-1 px-2 py-1 rounded-full bg-n-brand text-n-slate-1 shadow-md text-xs font-medium hover:opacity-90 focus:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      @click="toggle"
    >
      <span>+{{ providers.length }}</span>
      <Icon
        name="i-lucide-chevron-right"
        class="w-3 h-3 transition-transform"
        :class="{ 'rotate-90': isOpen }"
      />
    </button>
    <div
      v-if="isOpen"
      class="absolute right-0 mt-1 w-56 max-h-72 overflow-y-auto bg-n-glass-soft border border-n-border-glass-soft rounded-lg shadow-lg"
    >
      <button
        v-for="provider in providers"
        :key="provider.id"
        class="flex items-center gap-2 w-full px-3 py-2 text-left text-sm hover:bg-n-alpha-2"
        @click="pick(provider)"
      >
        <Avatar :name="provider.name" :src="provider.thumbnail" size="24" />
        <span class="truncate text-n-text-display">{{ provider.name }}</span>
      </button>
    </div>
  </div>
</template>
