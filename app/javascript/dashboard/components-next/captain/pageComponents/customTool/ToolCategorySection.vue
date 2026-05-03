<script setup>
import { ref } from 'vue';
import Policy from 'dashboard/components/policy.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  icon: { type: String, default: 'i-lucide-wrench' },
  iconColor: { type: String, default: 'text-n-blue-11' },
  bgColor: { type: String, default: 'bg-n-blue-3' },
  items: { type: Array, default: () => [] },
  hideToggle: { type: Boolean, default: false },
  collapsedByDefault: { type: Boolean, default: true },
  disabledToggleIds: { type: Array, default: () => [] },
});

defineEmits(['toggle', 'edit']);

const collapsed = ref(props.collapsedByDefault);
</script>

<template>
  <div class="rounded-xl border border-n-border-glass-soft bg-n-glass-soft">
    <!-- Category header -->
    <button
      class="flex items-center gap-3 w-full px-4 py-3 hover:bg-n-alpha-1 transition-colors rounded-t-xl"
      @click="collapsed = !collapsed"
    >
      <div
        class="flex items-center justify-center size-9 rounded-lg flex-shrink-0"
        :class="bgColor"
      >
        <span class="size-5" :class="[icon, iconColor]" />
      </div>
      <div class="flex flex-col items-start min-w-0 flex-1">
        <span class="text-sm font-semibold text-n-text-display truncate">
          {{ title }}
        </span>
        <span v-if="description" class="text-xs text-n-text-body/60">
          {{ description }}
        </span>
      </div>
      <span class="text-xs text-n-slate-9 flex-shrink-0 tabular-nums">
        {{ items.length }}
      </span>
      <span
        class="i-lucide-chevron-down size-4 text-n-slate-9 flex-shrink-0 transition-transform duration-200"
        :class="{ '-rotate-90': collapsed }"
      />
    </button>

    <!-- Items list -->
    <div
      v-show="!collapsed"
      class="border-t border-n-border-glass-soft divide-y divide-n-border-glass-soft"
    >
      <div
        v-for="item in items"
        :key="item.id"
        class="flex items-center gap-3 px-4 py-3 hover:bg-n-alpha-1 transition-colors group"
      >
        <!-- Item icon -->
        <div
          class="flex items-center justify-center size-8 rounded-lg bg-n-alpha-1 flex-shrink-0"
        >
          <span class="size-4 text-n-text-body/60" :class="item.icon" />
        </div>

        <!-- Name + description -->
        <button
          class="flex flex-col items-start min-w-0 flex-1 text-left"
          @click="$emit('edit', item)"
        >
          <span
            class="text-sm font-medium text-n-text-display truncate max-w-full"
          >
            {{ item.title }}
          </span>
          <span
            v-if="item.description"
            class="text-xs text-n-text-body/60 truncate max-w-full"
          >
            {{ item.description }}
          </span>
        </button>

        <!-- Enable/Disable toggle -->
        <Policy v-if="!hideToggle" :permissions="['administrator']">
          <div @click.stop>
            <Switch
              :model-value="item.enabled"
              :disabled="disabledToggleIds.includes(item.id)"
              @update:model-value="$emit('toggle', item)"
            />
          </div>
        </Policy>

        <!-- Action menu slot for custom tools -->
        <slot name="item-actions" :item="item" />
      </div>

      <!-- Empty state -->
      <div
        v-if="items.length === 0"
        class="flex items-center justify-center py-6 text-sm text-n-slate-9"
      >
        <slot name="empty">
          {{ $t('CAPTAIN.TOOLS_CATEGORY.EMPTY') }}
        </slot>
      </div>
    </div>
  </div>
</template>
