<script setup>
import { computed, ref } from 'vue';
import BaseBubble from './Base.vue';
import { useI18n } from 'vue-i18n';
import { CONTENT_TYPES } from '../constants.js';
import { useMessageContext } from '../provider.js';
import { useInbox } from 'dashboard/composables/useInbox';
import Button from 'dashboard/components-next/button/Button.vue';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

const { content, contentAttributes, contentType } = useMessageContext();
const { t } = useI18n();
const { isAWebWidgetInbox } = useInbox();

const selectedIndex = ref(null);
const isPendingConfirmation = ref(false);

const rawContentAttributes = computed(() => contentAttributes.value ?? {});

const formValues = computed(() => {
  const attrs = rawContentAttributes.value;
  const submittedValues = attrs.submittedValues ?? attrs.submitted_values ?? [];

  if (contentType.value === CONTENT_TYPES.FORM) {
    const items = attrs.items ?? [];

    if (submittedValues.length) {
      return submittedValues.map(submittedValue => {
        const item = items.find(
          formItem => formItem.name === submittedValue.name
        );
        return {
          title: submittedValue.value,
          value: submittedValue.value,
          label: item?.label,
        };
      });
    }

    return [];
  }

  if (contentType.value === CONTENT_TYPES.INPUT_SELECT) {
    const [item] = submittedValues;
    if (!item) return [];

    return [
      {
        title: item.title,
        value: item.value,
        label: '',
      },
    ];
  }

  return [];
});

const approvalRequestId = computed(() => {
  const attrs = rawContentAttributes.value;
  return attrs.approvalRequestId ?? attrs.approval_request_id;
});

const approvalOptionItems = computed(() => {
  const items = rawContentAttributes.value.items;
  return Array.isArray(items) ? items : [];
});

const showsApprovalButtons = computed(
  () =>
    approvalRequestId.value != null &&
    !formValues.value.length &&
    !isPendingConfirmation.value
);

const isInputSelectWithSelection = computed(
  () =>
    contentType.value === CONTENT_TYPES.INPUT_SELECT &&
    formValues.value.length > 0
);

const selectedOptionLabel = computed(() => {
  if (selectedIndex.value == null) return null;
  return (
    approvalOptionItems.value[selectedIndex.value]?.title ||
    approvalOptionItems.value[selectedIndex.value]?.label
  );
});

const onOptionSelect = index => {
  if (isPendingConfirmation.value) return;

  selectedIndex.value = index;
  isPendingConfirmation.value = true;

  const selectedLabel =
    approvalOptionItems.value[index]?.title ||
    approvalOptionItems.value[index]?.label;

  emitter.emit(BUS_EVENTS.APPROVAL_REQUEST_SELECTED, {
    approvalRequestId: approvalRequestId.value,
    selectedIndex: index,
    selectedLabel,
  });
};
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="csat">
    <span v-dompurify-html="content" :title="content" />
    <dl v-if="formValues.length" class="mt-4">
      <template v-for="item in formValues" :key="item.title">
        <dt
          class="mt-2 italic"
          :class="
            isInputSelectWithSelection ? 'text-n-green-11' : 'text-n-slate-11'
          "
        >
          {{ item.label || t('CONVERSATION.RESPONSE') }}
        </dt>
        <dd
          :class="
            isInputSelectWithSelection
              ? 'mt-0.5 max-w-full rounded-md bg-n-green-3 px-2 py-1.5 text-sm font-medium text-n-green-11'
              : ''
          "
        >
          {{ item.title }}
        </dd>
      </template>
    </dl>
    <div v-else-if="isPendingConfirmation" class="mt-4">
      <div class="text-xs text-n-slate-10 mb-1">
        {{ t('CONVERSATION.APPROVAL_DRAFT.SELECTED_OPTION') }}
      </div>
      <div
        class="rounded-md bg-n-iris-3 px-3 py-2 text-sm font-medium text-n-iris-11"
      >
        {{ selectedOptionLabel }}
      </div>
      <div class="text-xs text-n-slate-9 mt-2">
        {{ t('CONVERSATION.APPROVAL_DRAFT.EDIT_IN_REPLY_BOX') }}
      </div>
    </div>
    <div v-else-if="showsApprovalButtons" class="flex flex-col gap-2 mt-4">
      <Button
        v-for="(item, index) in approvalOptionItems"
        :key="item.title || item.label || index"
        :label="item.title || item.label"
        size="sm"
        variant="faded"
        @click="onOptionSelect(index)"
      />
    </div>
    <div v-else-if="isAWebWidgetInbox" class="my-2 font-medium">
      {{ t('CONVERSATION.NO_RESPONSE') }}
    </div>
  </BaseBubble>
</template>
