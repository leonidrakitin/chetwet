<script setup>
import { computed, ref } from 'vue';
import BaseBubble from './Base.vue';
import { useI18n } from 'vue-i18n';
import { CONTENT_TYPES } from '../constants.js';
import { useMessageContext } from '../provider.js';
import { useInbox } from 'dashboard/composables/useInbox';
import Button from 'dashboard/components-next/button/Button.vue';
import approvalRequestsApi from 'dashboard/api/captain/approvalRequests';

const { content, contentAttributes, contentType } = useMessageContext();
const { t } = useI18n();
const { isAWebWidgetInbox } = useInbox();

const isResolving = ref(false);

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
  () => approvalRequestId.value != null && !formValues.value.length
);

const onOptionSelect = async index => {
  if (isResolving.value) return;
  isResolving.value = true;
  try {
    await approvalRequestsApi.resolve(approvalRequestId.value, {
      selectedOptionIndex: index,
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Failed to resolve approval request', error);
  } finally {
    isResolving.value = false;
  }
};
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="csat">
    <span v-dompurify-html="content" :title="content" />
    <dl v-if="formValues.length" class="mt-4">
      <template v-for="item in formValues" :key="item.title">
        <dt class="text-n-slate-11 italic mt-2">
          {{ item.label || t('CONVERSATION.RESPONSE') }}
        </dt>
        <dd>{{ item.title }}</dd>
      </template>
    </dl>
    <div v-else-if="showsApprovalButtons" class="flex flex-col gap-2 mt-4">
      <Button
        v-for="(item, index) in approvalOptionItems"
        :key="item.title || item.label || index"
        :label="item.title || item.label"
        size="sm"
        variant="faded"
        :is-loading="isResolving"
        @click="onOptionSelect(index)"
      />
    </div>
    <div v-else-if="isAWebWidgetInbox" class="my-2 font-medium">
      {{ t('CONVERSATION.NO_RESPONSE') }}
    </div>
  </BaseBubble>
</template>
