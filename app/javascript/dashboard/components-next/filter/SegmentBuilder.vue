<script setup>
import { ref, useTemplateRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useContactFilterContext } from './contactProvider.js';

import Button from 'next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ConditionGroup from './ConditionGroup.vue';

const props = defineProps({
  segment: { type: Object, default: null },
});

const emit = defineEmits(['save', 'cancel']);
const { t } = useI18n();
const store = useStore();
const { filterTypes } = useContactFilterContext();

const DEFAULT_QUERY = {
  type: 'group',
  operator: 'and',
  children: [
    {
      type: 'condition',
      attributeKey: 'name',
      filterOperator: 'equal_to',
      values: '',
      attributeModel: 'standard',
    },
  ],
};

const segmentName = ref(props.segment?.name || '');
const segmentDescription = ref(props.segment?.description || '');
const query = ref(
  props.segment?.query ? JSON.parse(JSON.stringify(props.segment.query)) : { ...DEFAULT_QUERY, children: [...DEFAULT_QUERY.children] }
);
const previewCount = ref(null);
const isPreviewing = ref(false);

const conditionGroupRef = useTemplateRef('conditionGroupRef');

const handlePreview = async () => {
  if (!conditionGroupRef.value?.validate()) return;
  isPreviewing.value = true;
  try {
    const result = await store.dispatch('contactSegments/previewQuery', query.value);
    previewCount.value = result.count;
  } catch (error) {
    previewCount.value = null;
  } finally {
    isPreviewing.value = false;
  }
};

const handleSave = () => {
  if (!segmentName.value) return;
  if (!conditionGroupRef.value?.validate()) return;

  emit('save', {
    name: segmentName.value,
    description: segmentDescription.value,
    query: query.value,
  });
};
</script>

<template>
  <div class="grid gap-6 p-6 max-w-4xl">
    <h3 class="text-base font-medium leading-6 text-n-slate-12">
      {{ segment ? t('SEGMENT_BUILDER.EDIT_TITLE') : t('SEGMENT_BUILDER.CREATE_TITLE') }}
    </h3>

    <div class="grid gap-4">
      <Input
        v-model="segmentName"
        :label="t('SEGMENT_BUILDER.NAME_LABEL')"
        :placeholder="t('SEGMENT_BUILDER.NAME_PLACEHOLDER')"
      />
      <Input
        v-model="segmentDescription"
        :label="t('SEGMENT_BUILDER.DESCRIPTION_LABEL')"
        :placeholder="t('SEGMENT_BUILDER.DESCRIPTION_PLACEHOLDER')"
      />
    </div>

    <div>
      <h4 class="text-sm font-medium text-n-slate-11 mb-3">
        {{ t('SEGMENT_BUILDER.CONDITIONS_TITLE') }}
      </h4>
      <ConditionGroup
        ref="conditionGroupRef"
        v-model="query"
        :filter-types="filterTypes"
        :depth="1"
      />
    </div>

    <div class="flex items-center justify-between gap-2 pt-4 border-t border-n-weak">
      <div class="flex items-center gap-3">
        <Button
          sm
          faded
          blue
          :loading="isPreviewing"
          @click="handlePreview"
        >
          {{ t('SEGMENT_BUILDER.PREVIEW') }}
        </Button>
        <span
          v-if="previewCount !== null"
          class="text-sm text-n-slate-11"
        >
          {{ t('SEGMENT_BUILDER.PREVIEW_COUNT', { count: previewCount }) }}
        </span>
      </div>
      <div class="flex gap-2">
        <Button sm faded slate @click="emit('cancel')">
          {{ t('SEGMENT_BUILDER.CANCEL') }}
        </Button>
        <Button
          sm
          solid
          blue
          :disabled="!segmentName"
          @click="handleSave"
        >
          {{ t('SEGMENT_BUILDER.SAVE') }}
        </Button>
      </div>
    </div>
  </div>
</template>
