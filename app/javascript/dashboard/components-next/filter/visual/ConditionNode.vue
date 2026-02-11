<script setup>
import { computed } from 'vue';
import { Handle, Position } from '@vue-flow/core';

const props = defineProps({
  data: { type: Object, required: true },
});

const label = computed(() => {
  const { attributeKey, filterOperator, values } = props.data;
  const valueStr = Array.isArray(values) ? values.join(', ') : values;
  return `${attributeKey} ${filterOperator} ${valueStr || ''}`;
});
</script>

<template>
  <div class="bg-white border border-n-weak rounded-lg shadow-sm px-4 py-3 min-w-[240px] max-w-[320px]">
    <Handle type="target" :position="Position.Top" class="!bg-n-blue-9 !w-2 !h-2" />
    <div class="flex items-center gap-2">
      <span class="i-lucide-filter text-n-blue-11 flex-shrink-0" />
      <div class="text-sm text-n-slate-12 truncate">
        {{ label }}
      </div>
    </div>
    <Handle type="source" :position="Position.Bottom" class="!bg-n-blue-9 !w-2 !h-2" />
  </div>
</template>
