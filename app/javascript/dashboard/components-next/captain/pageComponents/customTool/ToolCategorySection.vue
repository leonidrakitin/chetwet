<script setup>
import { ref } from 'vue';
import Policy from 'dashboard/components/policy.vue';

defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  icon: { type: String, default: 'i-lucide-wrench' },
  iconColor: { type: String, default: 'text-n-blue-11' },
  bgColor: { type: String, default: 'bg-n-blue-3' },
  items: { type: Array, default: () => [] },
  hideToggle: { type: Boolean, default: false },
});

defineEmits(['toggle', 'edit']);

const collapsed = ref(false);
</script>

<template>
  <div class="rounded-xl border border-n-weak bg-n-solid-1 overflow-hidden">
    <!-- Category header -->
    <button
      class="flex items-center gap-3 w-full px-4 py-3 hover:bg-n-alpha-1 transition-colors"
      @click="collapsed = !collapsed"
    >
      <div
        class="flex items-center justify-center size-9 rounded-lg flex-shrink-0"
        :class="bgColor"
      >
        <span class="size-5" :class="[icon, iconColor]" />
      </div>
      <div class="flex flex-col items-start min-w-0 flex-1">
        <span class="text-sm font-semibold text-n-slate-12 truncate">
          {{ title }}
        </span>
        <span v-if="description" class="text-xs text-n-slate-10">
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
      class="border-t border-n-weak divide-y divide-n-weak"
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
          <span class="size-4 text-n-slate-10" :class="item.icon" />
        </div>

        <!-- Name + description -->
        <button
          class="flex flex-col items-start min-w-0 flex-1 text-left"
          @click="$emit('edit', item)"
        >
          <span class="text-sm font-medium text-n-slate-12 truncate max-w-full">
            {{ item.title }}
          </span>
          <span
            v-if="item.description"
            class="text-xs text-n-slate-10 truncate max-w-full"
          >
            {{ item.description }}
          </span>
        </button>

        <!-- Enable/Disable toggle -->
        <Policy v-if="!hideToggle" :permissions="['administrator']">
          <button
            class="relative inline-flex h-5 w-9 flex-shrink-0 cursor-pointer items-center rounded-full transition-colors duration-200"
            :class="item.enabled ? 'bg-n-teal-9' : 'bg-n-slate-7'"
            role="switch"
            :aria-checked="item.enabled"
            @click.stop="$emit('toggle', item)"
          >
            <span
              class="inline-block size-3.5 rounded-full bg-white shadow transition-transform duration-200"
              :class="item.enabled ? 'translate-x-[18px]' : 'translate-x-[3px]'"
            />
          </button>
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
