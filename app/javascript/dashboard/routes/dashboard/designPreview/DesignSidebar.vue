<script setup>
import { computed } from 'vue';

const props = defineProps({
  route: { type: String, required: true },
  expanded: { type: Boolean, default: false },
});

const emit = defineEmits(['update:route', 'update:expanded']);

const items = [
  { key: 'dialogues', icon: 'i-lucide-message-circle', label: 'Диалоги' },
  { key: 'captain', icon: 'i-woot-captain', label: 'Капитан' },
  { key: 'contacts', icon: 'i-lucide-users', label: 'Контакты' },
  { key: 'reports', icon: 'i-lucide-chart-spline', label: 'Отчёты' },
  { key: 'mail', icon: 'i-lucide-send', label: 'Mailings' },
  { key: 'sugg', icon: 'i-lucide-lightbulb', label: 'Suggestions' },
  { key: 'support', icon: 'i-lucide-life-buoy', label: 'Поддержка' },
  { key: 'settings', icon: 'i-lucide-bolt', label: 'Настройки' },
];

const railWidth = computed(() => (props.expanded ? '200px' : '76px'));
</script>

<template>
  <aside
    class="flex items-center h-full flex-shrink-0 pl-[14px] pr-[10px] py-[14px] transition-[width] duration-200 ease-out"
    :style="{ width: railWidth, minWidth: railWidth }"
  >
    <div class="flex flex-col gap-2 w-full items-center">
      <div
        v-for="it in items"
        :key="it.key"
        class="group relative w-full flex justify-center"
      >
        <button
          class="flex items-center transition-all duration-150 backdrop-blur-[14px] backdrop-saturate-150 cursor-pointer text-[13.5px] font-medium border h-12"
          :class="[
            expanded
              ? 'w-full rounded-[18px] justify-start px-[14px] gap-3'
              : 'rounded-full justify-center w-12 gap-0 p-0',
            route === it.key
              ? 'bg-[#1A1B1F] text-white border-[#1A1B1F] shadow-[0_10px_22px_-10px_rgba(0,0,0,0.45)]'
              : 'bg-white/70 text-[rgb(60,78,104)] border-white/90 shadow-[0_1px_0_rgba(255,255,255,0.9)_inset,0_6px_14px_-6px_rgba(28,56,96,0.1)]',
          ]"
          @click="emit('update:route', it.key)"
        >
          <span
            class="inline-flex flex-shrink-0 size-[18px]"
            :class="it.icon"
          />
          <span
            v-if="expanded"
            class="whitespace-nowrap overflow-hidden text-ellipsis"
          >
            {{ it.label }}
          </span>
        </button>
        <span
          v-if="!expanded"
          class="pointer-events-none absolute z-50 left-[calc(100%+12px)] top-1/2 bg-[#1A1B1F] text-white px-2.5 py-[5px] rounded-lg text-xs font-medium whitespace-nowrap shadow-[0_8px_20px_-8px_rgba(0,0,0,0.4)] opacity-0 -translate-y-1/2 -translate-x-1 group-hover:opacity-100 group-hover:translate-x-0 group-hover:-translate-y-1/2 transition-[opacity,transform] duration-150"
        >
          {{ it.label }}
        </span>
      </div>

      <div class="h-1.5" />

      <button
        class="flex items-center justify-center cursor-pointer transition-all duration-150 bg-white/55 text-[rgb(60,78,104)] border border-white/85 backdrop-blur-[14px] h-9"
        :class="expanded ? 'w-full rounded-xl' : 'rounded-full w-9'"
        :title="expanded ? 'Свернуть' : 'Раскрыть'"
        @click="emit('update:expanded', !expanded)"
      >
        <span
          class="inline-flex size-3.5"
          :class="expanded ? 'i-lucide-chevron-left' : 'i-lucide-chevron-right'"
        />
      </button>
    </div>
  </aside>
</template>
