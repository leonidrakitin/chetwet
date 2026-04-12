import { ref, computed } from 'vue';
import { useCaptain } from 'dashboard/composables/useCaptain';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useTrack } from 'dashboard/composables';
import { CAPTAIN_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import {
  CAPTAIN_ERROR_TYPES,
  CAPTAIN_GENERATION_FAILURE_REASONS,
} from 'dashboard/composables/captain/constants';
import approvalRequestsApi from 'dashboard/api/captain/approvalRequests';

const REWRITE_ACTIONS = [
  'improve',
  'fix_spelling_grammar',
  'casual',
  'professional',
  'expand',
  'shorten',
  'rephrase',
  'make_friendly',
  'make_formal',
  'simplify',
];

function getEventPrefix(action) {
  if (action === 'summarize') return 'SUMMARIZE';
  if (action === 'reply_suggestion') return 'REPLY_SUGGESTION';
  if (action === 'approval_draft') return 'APPROVAL_DRAFT';
  return 'REWRITE';
}

function buildPayload(action, conversationId, followUpCount = undefined) {
  const payload = { conversationId };

  if (REWRITE_ACTIONS.includes(action)) {
    payload.operation = action;
  }

  if (followUpCount !== undefined) {
    payload.followUpCount = followUpCount;
  }

  return payload;
}

function trackGenerationFailure({
  action,
  conversationId,
  followUpCount = undefined,
  stage,
  reason,
}) {
  useTrack(CAPTAIN_EVENTS.GENERATION_FAILED, {
    ...buildPayload(action, conversationId, followUpCount),
    stage,
    reason,
  });
}

export function useCopilotReply() {
  const { processEvent, followUp, currentChat } = useCaptain();
  const { updateUISettings } = useUISettings();

  const showEditor = ref(false);
  const isGenerating = ref(false);
  const isContentReady = ref(false);
  const generatedContent = ref('');
  const followUpContext = ref(null);
  const abortController = ref(null);

  const currentAction = ref(null);
  const followUpCount = ref(0);
  const trackedConversationId = ref(null);

  const approvalRequestContext = ref(null);

  const conversationId = computed(() => currentChat.value?.id);

  const isActive = computed(() => showEditor.value || isGenerating.value);
  const isButtonDisabled = computed(
    () => isGenerating.value || !isContentReady.value
  );
  const editorTransitionKey = computed(() =>
    isActive.value ? 'copilot' : 'rich'
  );

  const isApprovalDraftMode = computed(
    () => approvalRequestContext.value !== null
  );

  function reset(trackDismiss = true) {
    if (trackDismiss && generatedContent.value && currentAction.value) {
      const eventKey = `${getEventPrefix(currentAction.value)}_DISMISSED`;
      useTrack(
        CAPTAIN_EVENTS[eventKey],
        buildPayload(
          currentAction.value,
          trackedConversationId.value,
          followUpCount.value
        )
      );
    }

    if (abortController.value) {
      abortController.value.abort();
      abortController.value = null;
    }
    showEditor.value = false;
    isGenerating.value = false;
    isContentReady.value = false;
    generatedContent.value = '';
    followUpContext.value = null;
    currentAction.value = null;
    followUpCount.value = 0;
    trackedConversationId.value = null;
    approvalRequestContext.value = null;
  }

  function toggleEditor() {
    showEditor.value = !showEditor.value;
  }

  function setContentReady() {
    isContentReady.value = true;
  }

  async function execute(action, data) {
    if (action === 'ask_copilot') {
      updateUISettings({
        is_contact_sidebar_open: false,
        is_copilot_panel_open: true,
      });
      return;
    }

    reset(false);
    const requestController = new AbortController();
    abortController.value = requestController;
    isGenerating.value = true;
    isContentReady.value = false;
    currentAction.value = action;
    followUpCount.value = 0;
    trackedConversationId.value = conversationId.value;

    try {
      const {
        message: content,
        followUpContext: newContext,
        errorType,
      } = await processEvent(action, data, {
        signal: requestController.signal,
      });

      if (requestController.signal.aborted) return;
      if (errorType === CAPTAIN_ERROR_TYPES.ABORTED) {
        if (abortController.value === requestController) {
          isGenerating.value = false;
        }
        return;
      }

      generatedContent.value = content;
      followUpContext.value = newContext;
      if (content) {
        showEditor.value = true;
        const eventKey = `${getEventPrefix(action)}_USED`;
        useTrack(
          CAPTAIN_EVENTS[eventKey],
          buildPayload(action, trackedConversationId.value)
        );
      } else if (errorType && errorType !== CAPTAIN_ERROR_TYPES.ABORTED) {
        trackGenerationFailure({
          action,
          conversationId: trackedConversationId.value,
          stage: 'initial',
          reason: errorType,
        });
      } else {
        trackGenerationFailure({
          action,
          conversationId: trackedConversationId.value,
          stage: 'initial',
          reason: CAPTAIN_GENERATION_FAILURE_REASONS.EMPTY_RESPONSE,
        });
      }
      isGenerating.value = false;
    } catch (error) {
      if (
        requestController.signal.aborted ||
        error?.name === CAPTAIN_ERROR_TYPES.ABORT_ERROR ||
        error?.name === CAPTAIN_ERROR_TYPES.CANCELED_ERROR
      ) {
        return;
      }
      trackGenerationFailure({
        action,
        conversationId: trackedConversationId.value,
        stage: 'initial',
        reason: error?.name || CAPTAIN_GENERATION_FAILURE_REASONS.EXCEPTION,
      });
      isGenerating.value = false;
    } finally {
      if (abortController.value === requestController) {
        abortController.value = null;
      }
    }
  }

  async function startApprovalDraft(approvalRequestId, selectedIndex) {
    reset(false);

    const requestController = new AbortController();
    abortController.value = requestController;
    isGenerating.value = true;
    isContentReady.value = false;
    currentAction.value = 'approval_draft';
    followUpCount.value = 0;
    trackedConversationId.value = conversationId.value;

    approvalRequestContext.value = {
      approvalRequestId,
      selectedIndex,
    };

    try {
      const { data } = await approvalRequestsApi.generateDraft(
        approvalRequestId,
        { selectedOptionIndex: selectedIndex }
      );

      if (requestController.signal.aborted) return;

      const draft = data.draft || '';
      const newFollowUpContext = data.follow_up_context || null;

      generatedContent.value = draft;
      followUpContext.value = newFollowUpContext;

      if (draft) {
        showEditor.value = true;
        useTrack(
          CAPTAIN_EVENTS.APPROVAL_DRAFT_USED,
          buildPayload('approval_draft', trackedConversationId.value)
        );
      } else {
        trackGenerationFailure({
          action: 'approval_draft',
          conversationId: trackedConversationId.value,
          stage: 'initial',
          reason: CAPTAIN_GENERATION_FAILURE_REASONS.EMPTY_RESPONSE,
        });
      }
      isGenerating.value = false;
    } catch (error) {
      if (
        requestController.signal.aborted ||
        error?.name === CAPTAIN_ERROR_TYPES.ABORT_ERROR ||
        error?.name === CAPTAIN_ERROR_TYPES.CANCELED_ERROR
      ) {
        return;
      }
      trackGenerationFailure({
        action: 'approval_draft',
        conversationId: trackedConversationId.value,
        stage: 'initial',
        reason: error?.name || CAPTAIN_GENERATION_FAILURE_REASONS.EXCEPTION,
      });
      isGenerating.value = false;
    } finally {
      if (abortController.value === requestController) {
        abortController.value = null;
      }
    }
  }

  async function sendFollowUp(message) {
    if (!followUpContext.value || !message.trim()) return;

    const requestController = new AbortController();
    abortController.value = requestController;
    isGenerating.value = true;
    isContentReady.value = false;

    useTrack(CAPTAIN_EVENTS.FOLLOW_UP_SENT, {
      conversationId: trackedConversationId.value,
    });
    followUpCount.value += 1;

    try {
      const {
        message: content,
        followUpContext: updatedContext,
        errorType,
      } = await followUp({
        followUpContext: followUpContext.value,
        message,
        signal: requestController.signal,
      });

      if (requestController.signal.aborted) return;
      if (errorType === CAPTAIN_ERROR_TYPES.ABORTED) {
        if (abortController.value === requestController) {
          isGenerating.value = false;
        }
        return;
      }

      if (content) {
        generatedContent.value = content;
        followUpContext.value = updatedContext;
        showEditor.value = true;
      } else if (errorType && errorType !== CAPTAIN_ERROR_TYPES.ABORTED) {
        trackGenerationFailure({
          action: currentAction.value,
          conversationId: trackedConversationId.value,
          followUpCount: followUpCount.value,
          stage: 'follow_up',
          reason: errorType,
        });
      } else {
        trackGenerationFailure({
          action: currentAction.value,
          conversationId: trackedConversationId.value,
          followUpCount: followUpCount.value,
          stage: 'follow_up',
          reason: CAPTAIN_GENERATION_FAILURE_REASONS.EMPTY_RESPONSE,
        });
      }
      isGenerating.value = false;
    } catch (error) {
      if (
        requestController.signal.aborted ||
        error?.name === CAPTAIN_ERROR_TYPES.ABORT_ERROR ||
        error?.name === CAPTAIN_ERROR_TYPES.CANCELED_ERROR
      ) {
        return;
      }
      trackGenerationFailure({
        action: currentAction.value,
        conversationId: trackedConversationId.value,
        followUpCount: followUpCount.value,
        stage: 'follow_up',
        reason: error?.name || CAPTAIN_GENERATION_FAILURE_REASONS.EXCEPTION,
      });
      isGenerating.value = false;
    } finally {
      if (abortController.value === requestController) {
        abortController.value = null;
      }
    }
  }

  async function accept() {
    const content = generatedContent.value;

    if (approvalRequestContext.value) {
      try {
        await approvalRequestsApi.resolve(
          approvalRequestContext.value.approvalRequestId,
          {
            selectedOptionIndex: approvalRequestContext.value.selectedIndex,
            customResponse: content,
          }
        );

        useTrack(
          CAPTAIN_EVENTS.APPROVAL_DRAFT_APPLIED,
          buildPayload(
            'approval_draft',
            trackedConversationId.value,
            followUpCount.value
          )
        );
      } catch (error) {
        trackGenerationFailure({
          action: 'approval_draft',
          conversationId: trackedConversationId.value,
          stage: 'resolution',
          reason: error?.name || CAPTAIN_GENERATION_FAILURE_REASONS.EXCEPTION,
        });
        throw error;
      }
    } else if (currentAction.value) {
      const eventKey = `${getEventPrefix(currentAction.value)}_APPLIED`;
      useTrack(
        CAPTAIN_EVENTS[eventKey],
        buildPayload(
          currentAction.value,
          trackedConversationId.value,
          followUpCount.value
        )
      );
    }

    showEditor.value = false;
    generatedContent.value = '';
    followUpContext.value = null;
    currentAction.value = null;
    followUpCount.value = 0;
    trackedConversationId.value = null;
    approvalRequestContext.value = null;

    return content;
  }

  return {
    showEditor,
    isGenerating,
    isContentReady,
    generatedContent,
    followUpContext,
    approvalRequestContext,

    isActive,
    isButtonDisabled,
    editorTransitionKey,
    isApprovalDraftMode,

    reset,
    toggleEditor,
    setContentReady,
    execute,
    startApprovalDraft,
    sendFollowUp,
    accept,
  };
}
