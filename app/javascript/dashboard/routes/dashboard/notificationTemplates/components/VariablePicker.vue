<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  VARIABLE_KEYS,
  VARIABLE_CATEGORIES,
  toToken,
} from '../constants/variables';

const emit = defineEmits([
  'insert',
  'dragStart',
  'dragEnd',
  'highlightVariable',
]);

const { t } = useI18n();

const isOpen = ref(false);
const activeCategory = ref('all');
const pickerRef = ref(null);
const isDragging = ref(false);

const VARIABLE_CHIP_CLASSES = {
  client_name: 'bg-blue-100 text-blue-800 border-blue-200',
  service_name: 'bg-teal-100 text-teal-800 border-teal-200',
  branch_name: 'bg-amber-100 text-amber-800 border-amber-200',
  master_name: 'bg-violet-100 text-violet-800 border-violet-200',
  price: 'bg-red-100 text-red-800 border-red-200',
  date: 'bg-orange-100 text-orange-800 border-orange-200',
  time: 'bg-slate-200 text-slate-700 border-slate-300',
};

const allVariables = computed(() =>
  VARIABLE_KEYS.map(key => ({
    key,
    chipClass: VARIABLE_CHIP_CLASSES[key] ?? 'bg-slate-200 text-slate-700',
    label: t(`NOTIFICATION_TEMPLATES.VARIABLES.${key}`),
    description: t(`NOTIFICATION_TEMPLATES.VARIABLES.${key}_description`),
    example: t(`NOTIFICATION_TEMPLATES.VARIABLES.${key}_example`),
  }))
);

const categories = computed(() => [
  {
    key: 'all',
    label: t('NOTIFICATION_TEMPLATES.VARIABLES.CATEGORIES.ALL'),
    variables: allVariables.value,
  },
  ...VARIABLE_CATEGORIES.map(cat => ({
    key: cat.key,
    label: t(
      `NOTIFICATION_TEMPLATES.VARIABLES.CATEGORIES.${cat.key.toUpperCase()}`
    ),
    variables: cat.variables
      .map(k => allVariables.value.find(v => v.key === k))
      .filter(Boolean),
  })),
]);

const displayedVariables = computed(() => {
  const cat = categories.value.find(c => c.key === activeCategory.value);
  return cat?.variables ?? allVariables.value;
});

const createDragImage = (token, chipClass) => {
  const el = document.createElement('div');
  el.textContent = token;
  el.className = `inline-flex items-center rounded-full border px-1.5 py-0.5 text-[11px] font-medium leading-none opacity-60 ${chipClass}`;
  el.style.cssText =
    'position: absolute; left: -9999px; top: 0; pointer-events: none; white-space: nowrap;';
  document.body.appendChild(el);
  return el;
};

const onDragStart = (event, key) => {
  const variable = displayedVariables.value.find(v => v.key === key);
  const chipClass = variable?.chipClass ?? 'bg-slate-200 text-slate-700';
  event.dataTransfer.setData('text/plain', toToken(key));
  event.dataTransfer.effectAllowed = 'copy';
  isDragging.value = true;
  const dragImage = createDragImage(toToken(key), chipClass);
  event.dataTransfer.setDragImage(dragImage, 0, 0);
  requestAnimationFrame(() => dragImage.remove());
  emit('dragStart', key);
};

const onDragEnd = () => {
  isDragging.value = false;
  emit('dragEnd');
};

const onVariableMouseEnter = key => {
  if (!isDragging.value) emit('highlightVariable', key);
};

const onVariableMouseLeave = () => {
  if (!isDragging.value) emit('highlightVariable', null);
};

const insert = k => {
  emit('insert', toToken(k));
  isOpen.value = false;
};

const handleClickOutside = e => {
  if (pickerRef.value && !pickerRef.value.contains(e.target)) {
    isOpen.value = false;
  }
};

onMounted(() => document.addEventListener('mousedown', handleClickOutside));
onUnmounted(() =>
  document.removeEventListener('mousedown', handleClickOutside)
);
</script>

<template>
  <div ref="pickerRef" class="relative">
    <!-- Trigger button -->
    <button
      type="button"
      class="inline-flex items-center gap-1.5 rounded-md border border-n-border-glass-soft bg-n-alpha-1 px-2.5 py-1.5 text-xs font-medium text-n-text-body hover:bg-n-alpha-2 hover:text-n-text-display transition-colors"
      @click="isOpen = !isOpen"
    >
      <span class="i-lucide-braces size-3.5" />
      {{ t('NOTIFICATION_TEMPLATES.VARIABLES.PICKER_BUTTON') }}
      <span
        class="i-lucide-chevron-down size-3 transition-transform"
        :class="{ 'rotate-180': isOpen }"
      />
    </button>

    <!-- Popup -->
    <div
      v-if="isOpen"
      class="absolute bottom-full mb-1.5 left-0 z-50 w-72 rounded-xl border border-n-border-glass-soft bg-white dark:bg-n-glass-strong shadow-lg"
    >
      <!-- Category tabs -->
      <div
        class="flex gap-0.5 border-b border-n-border-glass-soft px-2 pt-2 overflow-x-auto"
      >
        <button
          v-for="cat in categories"
          :key="cat.key"
          type="button"
          class="whitespace-nowrap rounded-t-md px-2.5 py-1.5 text-xs font-medium transition-colors border-b-2 -mb-px flex-shrink-0"
          :class="
            activeCategory === cat.key
              ? 'text-n-brand border-n-brand'
              : 'text-n-text-body/60 border-transparent hover:text-n-text-display'
          "
          @click="activeCategory = cat.key"
        >
          {{ cat.label }}
        </button>
      </div>

      <!-- Variable list -->
      <div class="flex flex-col gap-0.5 p-2 max-h-52 overflow-y-auto">
        <div
          v-for="v in displayedVariables"
          :key="v.key"
          draggable="true"
          class="flex items-center gap-2 rounded-lg px-2 py-1.5 cursor-grab hover:bg-n-alpha-2 active:cursor-grabbing transition-colors"
          @click="insert(v.key)"
          @dragstart="onDragStart($event, v.key)"
          @dragend="onDragEnd"
          @mouseenter="onVariableMouseEnter(v.key)"
          @mouseleave="onVariableMouseLeave"
        >
          <span
            class="inline-flex flex-shrink-0 items-center rounded-full border px-1.5 py-0.5 text-[11px] font-medium leading-none"
            :class="v.chipClass"
          >
            {{ toToken(v.key) }}
          </span>
          <span class="text-xs text-n-text-body truncate min-w-0">
            {{ v.description }}
          </span>
        </div>
      </div>

      <!-- Footer hint -->
      <div
        class="border-t border-n-border-glass-soft px-3 py-1.5 text-[10px] text-n-slate-9 flex items-center gap-1"
      >
        <span class="i-lucide-mouse-pointer-2 size-3" />
        {{ t('NOTIFICATION_TEMPLATES.VARIABLES.PICKER_HINT') }}
      </div>
    </div>
  </div>
</template>
