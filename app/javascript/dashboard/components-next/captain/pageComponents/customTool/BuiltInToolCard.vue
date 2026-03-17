<script setup>
import { computed } from 'vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Policy from 'dashboard/components/policy.vue';

const props = defineProps({
  id: {
    type: String,
    required: true,
  },
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: '',
  },
  enabled: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['toggle']);

const ICON_MAP = {
  'note-add': 'i-lucide-notebook-pen',
  'eye-off': 'i-lucide-eye-off',
  'exclamation-triangle': 'i-lucide-triangle-alert',
  tag: 'i-lucide-tag',
  search: 'i-lucide-search',
  checkmark: 'i-lucide-check',
  'user-switch': 'i-lucide-user-round-cog',
  calendar: 'i-lucide-calendar',
  clock: 'i-lucide-clock',
  list: 'i-lucide-list',
  currency: 'i-lucide-banknote',
  'shopping-bag': 'i-lucide-shopping-bag',
};

const lucideIcon = computed(() => ICON_MAP[props.icon] || 'i-lucide-wrench');

const handleToggle = () => {
  emit('toggle', { id: props.id, enabled: !props.enabled });
};
</script>

<template>
  <CardLayout layout="row">
    <div class="flex items-center gap-3 flex-1 min-w-0">
      <div
        class="flex items-center justify-center size-8 rounded-lg bg-n-alpha-2 shrink-0"
      >
        <i :class="lucideIcon" class="text-base text-n-slate-11" />
      </div>
      <div class="flex flex-col gap-0.5 min-w-0 flex-1">
        <span class="text-sm font-medium text-n-slate-12 truncate">
          {{ title }}
        </span>
        <span v-if="description" class="text-xs text-n-slate-11 truncate">
          {{ description }}
        </span>
      </div>
    </div>
    <Policy :permissions="['administrator']">
      <Switch :model-value="enabled" @change="handleToggle" />
    </Policy>
  </CardLayout>
</template>
