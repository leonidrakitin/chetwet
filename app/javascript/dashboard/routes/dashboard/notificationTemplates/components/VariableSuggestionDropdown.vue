<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { VARIABLE_CATEGORIES } from '../constants/variables';

const props = defineProps({
  searchTerm: { type: String, default: '' },
  top: { type: Number, default: 0 },
  left: { type: Number, default: 0 },
  selectedIdx: { type: Number, default: 0 },
});

const emit = defineEmits(['select']);

const CATEGORY_ICONS = {
  client: 'i-lucide-user',
  appointment: 'i-lucide-calendar',
  payment: 'i-lucide-credit-card',
  datetime: 'i-lucide-clock',
};

const { t } = useI18n();

const collapsed = ref({});

const toggleCategory = key => {
  collapsed.value[key] = !collapsed.value[key];
};

const isSearching = computed(() => props.searchTerm.length > 0);

const filteredCategories = computed(() => {
  const term = props.searchTerm.toLowerCase();
  return VARIABLE_CATEGORIES.map(cat => {
    const vars = cat.variables.filter(k => {
      if (!term) return true;
      return (
        k.includes(term) ||
        t(`NOTIFICATION_TEMPLATES.VARIABLES.${k}`).toLowerCase().includes(term)
      );
    });
    return { ...cat, variables: vars };
  }).filter(cat => cat.variables.length > 0);
});

const filteredKeys = computed(() =>
  filteredCategories.value.flatMap(cat => cat.variables)
);

const getFlatIndex = key => filteredKeys.value.indexOf(key);

defineExpose({ filteredKeys });
</script>

<template>
  <div
    data-variable-suggestion
    class="z-50 min-w-[15rem] max-h-64 overflow-y-auto rounded-xl border border-n-weak bg-n-solid-1 shadow-lg py-1"
    :style="{ top: `${top}px`, left: `${left}px` }"
  >
    <p v-if="!filteredKeys.length" class="px-3 py-2 text-xs text-n-slate-9">
      {{ t('NOTIFICATION_TEMPLATES.VARIABLES.NO_MATCH') }}
    </p>

    <template v-for="cat in filteredCategories" :key="cat.key">
      <!-- Category header -->
      <button
        type="button"
        class="flex w-full items-center gap-2 px-3 py-1.5 text-xs font-semibold uppercase tracking-wide text-n-slate-9 hover:bg-n-alpha-1 transition-colors"
        @mousedown.prevent="toggleCategory(cat.key)"
      >
        <span
          :class="CATEGORY_ICONS[cat.key] || 'i-lucide-tag'"
          class="size-3.5 flex-shrink-0"
        />
        <span class="flex-1 text-left">
          {{
            t(
              `NOTIFICATION_TEMPLATES.VARIABLES.CATEGORIES.${cat.key.toUpperCase()}`
            )
          }}
        </span>
        <span
          class="size-3 flex-shrink-0 transition-transform duration-150 i-lucide-chevron-down"
          :class="[collapsed[cat.key] && !isSearching ? '-rotate-90' : '']"
        />
      </button>

      <!-- Variables in category -->
      <div v-show="!collapsed[cat.key] || isSearching" class="pb-0.5">
        <button
          v-for="key in cat.variables"
          :key="key"
          type="button"
          class="w-full rounded-lg px-3 py-1.5 pl-8 text-left transition-colors hover:bg-n-alpha-2"
          :class="{ 'bg-n-alpha-2': getFlatIndex(key) === selectedIdx }"
          @mousedown.prevent="emit('select', key)"
        >
          <p class="text-sm font-medium text-n-slate-12">
            {{ t(`NOTIFICATION_TEMPLATES.VARIABLES.${key}`) }}
          </p>
          <p class="text-xs text-n-slate-9">
            {{ t(`NOTIFICATION_TEMPLATES.VARIABLES.${key}_description`) }}
          </p>
        </button>
      </div>
    </template>
  </div>
</template>
