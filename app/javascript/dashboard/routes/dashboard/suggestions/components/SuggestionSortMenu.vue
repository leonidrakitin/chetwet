<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';

const model = defineModel({ type: String, default: 'votes' });

const { t } = useI18n();

const isMenuOpen = ref(false);

const sortOptions = computed(() => [
  { label: t('SUGGESTIONS.SORT_VOTES'), value: 'votes' },
  { label: t('SUGGESTIONS.SORT_LATEST'), value: 'latest' },
]);

const activeLabel = computed(() => {
  const selected = sortOptions.value.find(o => o.value === model.value);
  return selected?.label ?? t('SUGGESTIONS.SORT_VOTES');
});

const onSortChange = value => {
  model.value = value;
  isMenuOpen.value = false;
};
</script>

<template>
  <div class="relative">
    <Button
      icon="i-lucide-arrow-down-up"
      color="slate"
      size="sm"
      variant="ghost"
      class="w-8 shrink-0"
      :class="isMenuOpen ? 'bg-n-alpha-2' : ''"
      @click="isMenuOpen = !isMenuOpen"
    />
    <div
      v-if="isMenuOpen"
      v-on-clickaway="() => (isMenuOpen = false)"
      class="absolute top-full mt-1 ltr:-right-32 rtl:-left-32 sm:ltr:right-0 sm:rtl:left-0 flex flex-col gap-4 bg-n-alpha-3 backdrop-blur-[100px] border border-n-weak w-72 rounded-xl p-4 z-20"
    >
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm text-n-slate-12">
          {{ t('SUGGESTIONS.SORT_BY_LABEL') }}
        </span>
        <SelectMenu
          :model-value="model"
          :options="sortOptions"
          :label="activeLabel"
          @update:model-value="onSortChange"
        />
      </div>
    </div>
  </div>
</template>
