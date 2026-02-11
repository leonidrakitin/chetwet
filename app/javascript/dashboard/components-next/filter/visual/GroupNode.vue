<script setup>
import { computed } from 'vue';
import { Handle, Position } from '@vue-flow/core';

const props = defineProps({
  data: { type: Object, required: true },
});

const operatorLabel = computed(() => {
  return props.data.operator?.toUpperCase() || 'AND';
});

const operatorColor = computed(() => {
  return props.data.operator === 'or'
    ? 'bg-n-amber-3 text-n-amber-11 border-n-amber-6'
    : 'bg-n-blue-3 text-n-blue-11 border-n-blue-6';
});
</script>

<template>
  <div
    class="border rounded-lg shadow-sm px-4 py-3 min-w-[120px]"
    :class="operatorColor"
  >
    <Handle type="target" :position="Position.Top" class="!bg-n-slate-9 !w-2 !h-2" />
    <div class="flex items-center gap-2 justify-center">
      <span
        :class="
          data.operator === 'or' ? 'i-woot-logic-or' : 'i-lucide-ampersands'
        "
      />
      <span class="text-sm font-medium">{{ operatorLabel }}</span>
      <span class="text-xs opacity-60">({{ data.childCount }} conditions)</span>
    </div>
    <Handle type="source" :position="Position.Bottom" class="!bg-n-slate-9 !w-2 !h-2" />
  </div>
</template>
