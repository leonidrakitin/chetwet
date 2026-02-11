<script setup>
import { ref, computed, watch } from 'vue';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';

import ConditionNode from './ConditionNode.vue';
import GroupNode from './GroupNode.vue';
import OperatorEdge from './OperatorEdge.vue';
import { treeToFlow } from './treeToFlow.js';
import { flowToTree } from './flowToTree.js';

import Button from 'next/button/Button.vue';

const props = defineProps({
  query: { type: Object, default: null },
});

const emit = defineEmits(['update:query', 'switchToForm']);

const { fitView } = useVueFlow();

const nodes = ref([]);
const edges = ref([]);

const nodeTypes = {
  conditionNode: ConditionNode,
  groupNode: GroupNode,
};

const edgeTypes = {
  operatorEdge: OperatorEdge,
};

// Convert query tree to flow when query changes
watch(
  () => props.query,
  newQuery => {
    if (newQuery) {
      const { nodes: flowNodes, edges: flowEdges } = treeToFlow(newQuery);
      nodes.value = flowNodes;
      edges.value = flowEdges;
      setTimeout(() => fitView({ padding: 0.2 }), 100);
    }
  },
  { immediate: true, deep: true }
);

const syncTreeFromFlow = () => {
  const tree = flowToTree(nodes.value, edges.value);
  if (tree) {
    emit('update:query', tree);
  }
};
</script>

<template>
  <div class="relative w-full h-[500px] border border-n-weak rounded-lg overflow-hidden bg-white">
    <div class="absolute top-3 right-3 z-10">
      <Button
        xs
        faded
        slate
        @click="emit('switchToForm')"
      >
        <span class="i-lucide-list mr-1" />
        Form View
      </Button>
    </div>
    <VueFlow
      v-model:nodes="nodes"
      v-model:edges="edges"
      :node-types="nodeTypes"
      :edge-types="edgeTypes"
      :default-viewport="{ zoom: 0.8 }"
      fit-view-on-init
      @nodes-change="syncTreeFromFlow"
    >
      <Background />
      <Controls />
    </VueFlow>
  </div>
</template>
