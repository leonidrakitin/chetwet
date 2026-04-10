<script setup>
import { computed, ref } from 'vue';
import BaseBubble from './Base.vue';
import { useI18n } from 'vue-i18n';
import { CONTENT_TYPES } from '../constants.js';
import { useMessageContext } from '../provider.js';
import { useInbox } from 'dashboard/composables/useInbox';
import Button from 'dashboard/components-next/button/Button.vue';
import approvalRequestsApi from 'dashboard/api/captain/approvalRequests';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

const { content, contentAttributes, contentType } = useMessageContext();
const { t } = useI18n();
const { isAWebWidgetInbox } = useInbox();

const isResolving = ref(false);
const isGeneratingDraft = ref(false);
const generatedDraft = ref('');
const selectedIndex = ref(null);

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

const isInputSelectWithSelection = computed(
  () =>
    contentType.value === CONTENT_TYPES.INPUT_SELECT &&
    formValues.value.length > 0
);

const hasDraft = computed(() => generatedDraft.value.length > 0);

const onOptionSelect = async index => {
  if (isGeneratingDraft.value) return;
  isGeneratingDraft.value = true;
  selectedIndex.value = index;
  generatedDraft.value = '';
  try {
    const { data } = await approvalRequestsApi.generateDraft(
      approvalRequestId.value,
      { selectedOptionIndex: index }
    );
    generatedDraft.value = data.draft || '';
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Failed to generate draft', error);
  } finally {
    isGeneratingDraft.value = false;
  }
};

const onInsertDraft = () => {
  emitter.emit(BUS_EVENTS.INSERT_INTO_RICH_EDITOR, generatedDraft.value);
};

const onConfirmDraft = async () => {
  if (isResolving.value) return;
  isResolving.value = true;
  try {
    await approvalRequestsApi.resolve(approvalRequestId.value, {
      selectedOptionIndex: selectedIndex.value,
      customResponse: generatedDraft.value,
    });
    generatedDraft.value = '';
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Failed to resolve approval request', error);
  } finally {
    isResolving.value = false;
  }
};

const onSuggestOwn = () => {
  generatedDraft.value = '';
  selectedIndex.value = null;
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
    <div v-else-if="hasDraft" class="mt-4 flex flex-col gap-2">
      <div
        class="rounded-md bg-n-alpha-2 px-3 py-2 text-sm text-n-slate-12 whitespace-pre-wrap"
      >
        {{ generatedDraft }}
      </div>
      <div class="flex gap-2">
        <Button
          :label="t('CONVERSATION.APPROVAL_DRAFT.INSERT')"
          size="sm"
          variant="faded"
          color-scheme="primary"
          @click="onInsertDraft"
        />
        <Button
          :label="t('CONVERSATION.APPROVAL_DRAFT.CONFIRM')"
          size="sm"
          variant="faded"
          color-scheme="success"
          :is-loading="isResolving"
          @click="onConfirmDraft"
        />
        <Button
          :label="t('CONVERSATION.APPROVAL_DRAFT.SUGGEST_OWN')"
          size="sm"
          variant="faded"
          @click="onSuggestOwn"
        />
      </div>
    </div>
    <div v-else-if="showsApprovalButtons" class="flex flex-col gap-2 mt-4">
      <Button
        v-for="(item, index) in approvalOptionItems"
        :key="item.title || item.label || index"
        :label="item.title || item.label"
        size="sm"
        variant="faded"
        :is-loading="isGeneratingDraft"
        @click="onOptionSelect(index)"
      />
    </div>
    <div v-else-if="isAWebWidgetInbox" class="my-2 font-medium">
      {{ t('CONVERSATION.NO_RESPONSE') }}
    </div>
  </BaseBubble>
</template>
