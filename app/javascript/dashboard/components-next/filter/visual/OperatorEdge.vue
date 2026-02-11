<script setup>
import { computed } from 'vue';
import { BaseEdge, getSmoothStepPath } from '@vue-flow/core';

const props = defineProps({
  id: { type: String, required: true },
  sourceX: { type: Number, required: true },
  sourceY: { type: Number, required: true },
  targetX: { type: Number, required: true },
  targetY: { type: Number, required: true },
  sourcePosition: { type: String, default: 'bottom' },
  targetPosition: { type: String, default: 'top' },
  data: { type: Object, default: () => ({}) },
  markerEnd: { type: String, default: '' },
});

const path = computed(() => {
  return getSmoothStepPath({
    sourceX: props.sourceX,
    sourceY: props.sourceY,
    sourcePosition: props.sourcePosition,
    targetX: props.targetX,
    targetY: props.targetY,
    targetPosition: props.targetPosition,
  });
});

const edgeColor = computed(() => {
  return props.data?.operator === 'or' ? '#d97706' : '#3b82f6';
});
</script>

<template>
  <BaseEdge
    :id="id"
    :path="path[0]"
    :marker-end="markerEnd"
    :style="{ stroke: edgeColor, strokeWidth: 2 }"
  />
</template>
