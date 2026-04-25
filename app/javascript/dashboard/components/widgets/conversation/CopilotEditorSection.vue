<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import CopilotEditor from 'dashboard/components/widgets/WootWriter/CopilotEditor.vue';
import CaptainLoader from 'dashboard/components/widgets/conversation/copilot/CaptainLoader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  showCopilotEditor: {
    type: Boolean,
    default: false,
  },
  isGeneratingContent: {
    type: Boolean,
    default: false,
  },
  generatedContent: {
    type: String,
    default: '',
  },
  isPopout: {
    type: Boolean,
    default: false,
  },
  isApprovalMode: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'focus',
  'blur',
  'clearSelection',
  'contentReady',
  'send',
  'improve',
  'submitAsIs',
]);

const { t } = useI18n();

const copilotEditorContent = ref('');

const hasContent = computed(() => copilotEditorContent.value.trim().length > 0);

const onFocus = () => {
  emit('focus');
};

const onBlur = () => {
  emit('blur');
};

const clearEditorSelection = () => {
  emit('clearSelection');
};

const onSend = () => {
  // Approval mode requires an explicit choice (improve vs send-as-is) so
  // the editor must not silently clear the input or fire the follow-up
  // pipeline on Enter — the buttons below are the canonical entry points.
  if (props.isApprovalMode) return;
  emit('send', copilotEditorContent.value);
  copilotEditorContent.value = '';
};

const onImprove = () => {
  if (!hasContent.value || props.isGeneratingContent) return;
  emit('improve', copilotEditorContent.value);
};

const onSubmitAsIs = () => {
  if (!hasContent.value || props.isGeneratingContent) return;
  emit('submitAsIs', copilotEditorContent.value);
};
</script>

<template>
  <Transition
    mode="out-in"
    enter-active-class="transition-all duration-300 ease-out"
    enter-from-class="opacity-0 translate-y-2 scale-[0.98]"
    enter-to-class="opacity-100 translate-y-0 scale-100"
    leave-active-class="transition-all duration-200 ease-in"
    leave-from-class="opacity-100 translate-y-0 scale-100"
    leave-to-class="opacity-0 translate-y-2 scale-[0.98]"
    @after-enter="emit('contentReady')"
  >
    <div v-if="showCopilotEditor && !isGeneratingContent" key="copilot-editor">
      <CopilotEditor
        v-model="copilotEditorContent"
        class="copilot-editor"
        :generated-content="generatedContent"
        :min-height="4"
        :enabled-menu-options="[]"
        :is-popout="isPopout"
        @focus="onFocus"
        @blur="onBlur"
        @clear-selection="clearEditorSelection"
        @send="onSend"
      />
      <div
        v-if="isApprovalMode"
        class="flex justify-end gap-2 mb-4 -mt-2"
        data-testid="approval-draft-actions"
      >
        <NextButton
          slate
          faded
          sm
          :disabled="!hasContent || isGeneratingContent"
          :label="t('CONVERSATION.APPROVAL_DRAFT.SEND_AS_IS')"
          data-testid="approval-send-as-is"
          @click="onSubmitAsIs"
        />
        <NextButton
          solid
          sm
          class="bg-n-iris-9 text-white"
          :disabled="!hasContent || isGeneratingContent"
          :label="t('CONVERSATION.APPROVAL_DRAFT.IMPROVE')"
          data-testid="approval-improve"
          @click="onImprove"
        />
      </div>
    </div>
    <div
      v-else-if="isGeneratingContent"
      key="loading-state"
      class="bg-n-iris-5 rounded min-h-[4.75rem] w-full mb-4 p-4 flex items-start"
    >
      <div class="flex items-center gap-2">
        <CaptainLoader class="text-n-iris-10 size-4" />
        <span class="text-sm text-n-iris-10">
          {{ $t('CONVERSATION.REPLYBOX.COPILOT_THINKING') }}
        </span>
      </div>
    </div>
  </Transition>
</template>

<style lang="scss">
.copilot-editor {
  .ProseMirror-menubar {
    display: none;
  }
}
</style>
