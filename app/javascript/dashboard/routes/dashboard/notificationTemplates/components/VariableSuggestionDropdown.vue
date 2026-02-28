<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { VARIABLE_KEYS } from '../constants/variables';

const props = defineProps({
  searchTerm: { type: String, default: '' },
  top: { type: Number, default: 0 },
  left: { type: Number, default: 0 },
  selectedIdx: { type: Number, default: 0 },
});

const emit = defineEmits(['select']);

const { t } = useI18n();

const filteredKeys = computed(() => {
  const term = props.searchTerm.toLowerCase();
  if (!term) return VARIABLE_KEYS;
  return VARIABLE_KEYS.filter(
    k =>
      k.includes(term) ||
      t(`NOTIFICATION_TEMPLATES.VARIABLES.${k}`).toLowerCase().includes(term)
  );
});

defineExpose({ filteredKeys });
</script>

<template>
  <div
    class="absolute z-50 min-w-[13rem] max-h-56 overflow-y-auto rounded-xl border border-n-weak bg-n-solid-1 shadow-lg p-1"
    :style="{ top: `${top}px`, left: `${left}px` }"
  >
    <p v-if="!filteredKeys.length" class="px-3 py-2 text-xs text-n-slate-9">
      {{ t('NOTIFICATION_TEMPLATES.VARIABLES.NO_MATCH') }}
    </p>
    <button
      v-for="(key, idx) in filteredKeys"
      :key="key"
      type="button"
      class="w-full rounded-lg px-3 py-2 text-left transition-colors hover:bg-n-alpha-2"
      :class="{ 'bg-n-alpha-2': idx === selectedIdx }"
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
