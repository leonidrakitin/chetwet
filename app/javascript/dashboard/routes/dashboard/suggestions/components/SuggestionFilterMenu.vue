<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';

const model = defineModel({ type: String, default: '' });

const { t } = useI18n();

const isMenuOpen = ref(false);

const statusOptions = computed(() => [
  { label: t('SUGGESTIONS.FILTER_ALL'), value: '' },
  { label: t('SUGGESTIONS.STATUS_PENDING'), value: 'pending' },
  { label: t('SUGGESTIONS.STATUS_APPROVED'), value: 'approved' },
  { label: t('SUGGESTIONS.STATUS_REJECTED'), value: 'rejected' },
]);

const activeLabel = computed(() => {
  const selected = statusOptions.value.find(o => o.value === model.value);
  return selected?.label ?? t('SUGGESTIONS.FILTER_ALL');
});

const hasActiveFilter = computed(() => model.value !== '');

const onStatusChange = value => {
  model.value = value;
  isMenuOpen.value = false;
};
</script>

<template>
  <div class="relative">
    <Button
      icon="i-lucide-list-filter"
      color="slate"
      size="sm"
      variant="ghost"
      class="relative w-8 shrink-0"
      :class="isMenuOpen ? 'bg-n-alpha-2' : ''"
      @click="isMenuOpen = !isMenuOpen"
    >
      <div
        v-if="hasActiveFilter"
        class="absolute top-0 right-0 w-2 h-2 rounded-full bg-n-brand"
      />
    </Button>
    <div
      v-if="isMenuOpen"
      v-on-clickaway="() => (isMenuOpen = false)"
      class="absolute top-full mt-1 ltr:right-0 rtl:left-0 flex flex-col gap-4 bg-n-alpha-3 backdrop-blur-[100px] border border-n-weak w-72 rounded-xl p-4 z-20"
    >
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm text-n-slate-12">
          {{ t('SUGGESTIONS.FILTER_STATUS_LABEL') }}
        </span>
        <SelectMenu
          :model-value="model"
          :options="statusOptions"
          :label="activeLabel"
          @update:model-value="onStatusChange"
        />
      </div>
    </div>
  </div>
</template>
