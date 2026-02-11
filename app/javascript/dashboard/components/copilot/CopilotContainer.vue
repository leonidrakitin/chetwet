<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import Copilot from 'dashboard/components-next/copilot/Copilot.vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useWindowSize } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import wootConstants from 'dashboard/constants/globals';
import { useCaptain } from 'dashboard/composables/useCaptain';

defineProps({
  conversationInboxType: {
    type: String,
    default: '',
  },
});

const store = useStore();
const { uiSettings, updateUISettings } = useUISettings();
const { captainEnabled } = useCaptain();
const { width: windowWidth } = useWindowSize();

const currentUser = useMapGetter('getCurrentUser');
const assistants = useMapGetter('captainAssistants/getRecords');
const uiFlags = useMapGetter('captainAssistants/getUIFlags');
const inboxAssistant = useMapGetter('getCopilotAssistant');
const currentChat = useMapGetter('getSelectedChat');

const source = computed(() => {
  const channel = currentChat.value?.meta?.channel || 'default';
  const contactId = currentChat.value?.meta?.sender?.id;
  return contactId ? `${channel}-contact-${contactId}` : channel;
});

const isSmallScreen = computed(
  () => windowWidth.value < wootConstants.SMALL_SCREEN_BREAKPOINT
);

const selectedCopilotThreadId = ref(null);
const messages = computed(() =>
  store.getters['copilotMessages/getMessagesByThreadId'](
    selectedCopilotThreadId.value
  )
);

const selectedAssistantId = ref(null);

const activeAssistant = computed(() => {
  const preferredId = uiSettings.value.preferred_captain_assistant_id;

  // If the user has selected a specific assistant, it takes first preference for Copilot.
  if (preferredId) {
    const preferredAssistant = assistants.value.find(a => a.id === preferredId);
    // Return the preferred assistant if found, otherwise continue to next cases
    if (preferredAssistant) return preferredAssistant;
  }

  // If the above is not available, the assistant connected to the inbox takes preference.
  if (inboxAssistant.value) {
    const inboxMatchedAssistant = assistants.value.find(
      a => a.id === inboxAssistant.value.id
    );
    if (inboxMatchedAssistant) return inboxMatchedAssistant;
  }
  // If neither of the above is available, the first assistant in the account takes preference.
  return assistants.value[0];
});

const closeCopilotPanel = () => {
  if (isSmallScreen.value && uiSettings.value?.is_copilot_panel_open) {
    updateUISettings({
      is_contact_sidebar_open: false,
      is_copilot_panel_open: false,
    });
  }
};

const setAssistant = async assistant => {
  selectedAssistantId.value = assistant.id;
  await updateUISettings({
    preferred_captain_assistant_id: assistant.id,
  });
};

const shouldShowCopilotPanel = computed(() => {
  const { is_copilot_panel_open: isCopilotPanelOpen } = uiSettings.value;
  return (
    captainEnabled.value && isCopilotPanelOpen && !uiFlags.value.fetchingList
  );
});

const handleReset = () => {
  selectedCopilotThreadId.value = null;
};

const loadExistingThreadForSource = async () => {
  if (!activeAssistant.value?.id || !source.value) return;

  try {
    const threads = await store.dispatch('copilotThreads/get', {
      source: source.value,
      page: 1,
    });
    const existing = Array.isArray(threads) ? threads[0] : threads?.[0];
    if (existing?.id) {
      selectedCopilotThreadId.value = existing.id;
      await store.dispatch('copilotMessages/get', existing.id);
    }
  } catch {
    // Ignore - no existing thread for this source
  }
};

const sendMessage = async message => {
  try {
    if (selectedCopilotThreadId.value) {
      await store.dispatch('copilotMessages/create', {
        assistant_id: activeAssistant.value.id,
        conversation_id: currentChat.value?.id,
        threadId: selectedCopilotThreadId.value,
        message,
      });
    } else {
      const response = await store.dispatch('copilotThreads/create', {
        assistant_id: activeAssistant.value.id,
        conversation_id: currentChat.value?.id,
        message,
        source: source.value,
      });
      selectedCopilotThreadId.value = response.id;
      await store.dispatch('copilotMessages/get', response.id);
    }
  } catch (error) {
    useAlert(error.message);
  }
};

watch(
  source,
  () => {
    selectedCopilotThreadId.value = null;
  },
  { immediate: false }
);

watch(
  () => [shouldShowCopilotPanel.value, source.value, activeAssistant.value?.id],
  ([isOpen, , assistantId]) => {
    if (isOpen && assistantId && !selectedCopilotThreadId.value) {
      loadExistingThreadForSource();
    }
  },
  { immediate: true }
);

onMounted(() => {
  if (captainEnabled.value) {
    store.dispatch('captainAssistants/get');
  }
});
</script>

<template>
  <div
    v-if="shouldShowCopilotPanel"
    v-on-click-outside="() => closeCopilotPanel()"
    class="bg-n-surface-2 h-full overflow-hidden flex-col fixed top-0 ltr:right-0 rtl:left-0 z-40 w-full max-w-sm transition-transform duration-300 ease-in-out md:static md:w-[320px] md:min-w-[320px] ltr:border-l rtl:border-r border-n-weak 2xl:min-w-[360px] 2xl:w-[360px] shadow-lg md:shadow-none"
    :class="[
      {
        'md:flex': shouldShowCopilotPanel,
        'md:hidden': !shouldShowCopilotPanel,
      },
    ]"
  >
    <Copilot
      :messages="messages"
      :support-agent="currentUser"
      :conversation-inbox-type="conversationInboxType"
      :assistants="assistants"
      :active-assistant="activeAssistant"
      @set-assistant="setAssistant"
      @send-message="sendMessage"
      @reset="handleReset"
    />
  </div>
  <template v-else />
</template>
