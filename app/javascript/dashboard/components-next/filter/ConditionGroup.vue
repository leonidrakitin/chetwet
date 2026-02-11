<script setup>
import { computed, useTemplateRef } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'next/button/Button.vue';
import ConditionRow from './ConditionRow.vue';

const MAX_DEPTH = 3;
const MAX_NODES = 20;

const props = defineProps({
  filterTypes: { type: Array, required: true },
  depth: { type: Number, default: 1 },
  totalNodes: { type: Number, default: 0 },
  removable: { type: Boolean, default: false },
});

const emit = defineEmits(['remove', 'update:totalNodes']);
const { t } = useI18n();

const group = defineModel({ type: Object, required: true });

const operator = computed({
  get: () => group.value.operator,
  set: val => {
    group.value.operator = val;
  },
});

const toggleOperator = () => {
  operator.value = operator.value === 'and' ? 'or' : 'and';
};

const conditionRefs = useTemplateRef('conditionRefs');

const DEFAULT_CONDITION = {
  type: 'condition',
  attributeKey: 'name',
  filterOperator: 'equal_to',
  values: '',
  attributeModel: 'standard',
};

const canAddNodes = computed(() => {
  return countNodes(group.value) < MAX_NODES;
});

const canAddGroup = computed(() => {
  return props.depth < MAX_DEPTH && canAddNodes.value;
});

function countNodes(node) {
  if (!node) return 0;
  if (node.type === 'condition') return 1;
  if (node.type === 'group' && node.children) {
    return 1 + node.children.reduce((sum, child) => sum + countNodes(child), 0);
  }
  return 1;
}

const addCondition = () => {
  if (!canAddNodes.value) return;
  group.value.children.push({ ...DEFAULT_CONDITION });
};

const addGroup = () => {
  if (!canAddGroup.value) return;
  group.value.children.push({
    type: 'group',
    operator: 'and',
    children: [{ ...DEFAULT_CONDITION }],
  });
};

const removeChild = index => {
  if (group.value.children.length <= 1) return;
  group.value.children.splice(index, 1);
};

const validate = () => {
  if (!conditionRefs.value) return true;
  return conditionRefs.value.every(ref => {
    if (ref.validate) return ref.validate();
    return true;
  });
};

defineExpose({ validate });
</script>

<template>
  <div
    class="border rounded-lg p-4 grid gap-3"
    :class="depth === 1 ? 'border-n-weak bg-n-alpha-1' : 'border-n-weak/60 bg-n-alpha-2'"
  >
    <div class="flex items-center justify-between">
      <button
        class="flex items-center gap-1 px-2 py-1 rounded text-sm font-medium cursor-pointer transition-colors"
        :class="
          operator === 'and'
            ? 'bg-n-blue-3 text-n-blue-11'
            : 'bg-n-amber-3 text-n-amber-11'
        "
        @click="toggleOperator"
      >
        <span
          :class="
            operator === 'and' ? 'i-lucide-ampersands' : 'i-woot-logic-or'
          "
        />
        {{ operator === 'and' ? t('FILTER.QUERY_DROPDOWN_LABELS.AND') : t('FILTER.QUERY_DROPDOWN_LABELS.OR') }}
      </button>
      <Button
        v-if="removable"
        xs
        ghost
        slate
        icon="i-lucide-trash"
        @click="emit('remove')"
      />
    </div>

    <ul class="grid gap-3 list-none">
      <template v-for="(child, index) in group.children" :key="index">
        <li v-if="child.type === 'condition'" class="list-none">
          <ConditionRow
            ref="conditionRefs"
            v-model:attribute-key="child.attributeKey"
            v-model:filter-operator="child.filterOperator"
            v-model:values="child.values"
            :filter-types="filterTypes"
            :show-query-operator="false"
            @remove="removeChild(index)"
          />
        </li>
        <li v-else-if="child.type === 'group'" class="list-none">
          <ConditionGroup
            ref="conditionRefs"
            v-model="group.children[index]"
            :filter-types="filterTypes"
            :depth="depth + 1"
            removable
            @remove="removeChild(index)"
          />
        </li>
      </template>
    </ul>

    <div class="flex gap-2">
      <Button
        xs
        ghost
        blue
        :disabled="!canAddNodes"
        @click="addCondition"
      >
        {{ t('CONTACTS_LAYOUT.FILTER.BUTTONS.ADD_FILTER') }}
      </Button>
      <Button
        v-if="canAddGroup"
        xs
        ghost
        slate
        @click="addGroup"
      >
        {{ t('SEGMENT_BUILDER.ADD_GROUP') }}
      </Button>
    </div>
  </div>
</template>
