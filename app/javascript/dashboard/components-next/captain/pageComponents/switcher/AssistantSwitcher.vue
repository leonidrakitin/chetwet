<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store.js';

import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const emit = defineEmits(['close', 'createAssistant']);

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const assistants = useMapGetter('captainAssistants/getRecords');

const currentAssistantId = computed(() => route.params.assistantId);

const isAssistantActive = assistant => {
  return assistant.id === Number(currentAssistantId.value);
};

const fetchDataForRoute = async (routeName, assistantId) => {
  const dataFetchMap = {
    captain_assistants_responses_index: async () => {
      await store.dispatch('captainResponses/get', { assistantId });
      await store.dispatch('captainResponses/fetchPendingCount', assistantId);
    },
    captain_assistants_responses_pending: async () => {
      await store.dispatch('captainResponses/get', {
        assistantId,
        status: 'pending',
      });
    },
    captain_assistants_documents_index: async () => {
      await store.dispatch('captainDocuments/get', { assistantId });
    },
    captain_assistants_scenarios_index: async () => {
      await store.dispatch('captainScenarios/get', { assistantId });
    },
    captain_assistants_playground_index: () => {
      // Playground doesn't need pre-fetching, it loads on interaction
    },
    captain_assistants_inboxes_index: async () => {
      await store.dispatch('captainInboxes/get', { assistantId });
    },
    captain_tools_index: async () => {
      await store.dispatch('captainCustomTools/get', { page: 1 });
    },
    captain_assistants_settings_index: async () => {
      await store.dispatch('captainAssistants/show', assistantId);
    },
  };

  const fetchFn = dataFetchMap[routeName];
  if (fetchFn) {
    await fetchFn();
  }
};

const handleAssistantChange = async assistant => {
  if (isAssistantActive(assistant)) return;

  const currentRouteName = route.name;
  const targetRouteName =
    currentRouteName || 'captain_assistants_responses_index';

  await fetchDataForRoute(targetRouteName, assistant.id);

  await router.push({
    name: targetRouteName,
    params: {
      accountId: route.params.accountId,
      assistantId: assistant.id,
    },
  });

  emit('close');
};

const openCreateAssistantDialog = () => {
  emit('createAssistant');
  emit('close');
};
</script>

<template>
  <div
    class="pt-5 pb-3 bg-n-alpha-3 backdrop-blur-[100px] outline outline-n-container outline-1 z-50 w-full rounded-xl shadow-md flex flex-col gap-4"
  >
    <div
      class="flex items-center justify-end gap-4 px-6 pb-3 border-b border-n-alpha-2"
    >
      <Button
        :label="t('CAPTAIN.ASSISTANT_SWITCHER.NEW_ASSISTANT')"
        color="slate"
        icon="i-lucide-plus"
        size="sm"
        class="!bg-n-alpha-2 hover:!bg-n-alpha-3"
        @click="openCreateAssistantDialog"
      />
    </div>
    <div v-if="assistants.length > 0" class="flex flex-col gap-1 px-3 pb-1">
      <button
        v-for="assistant in assistants"
        :key="assistant.id"
        type="button"
        class="flex items-center gap-3 w-full px-3 py-2.5 rounded-xl text-left transition-colors"
        :class="
          isAssistantActive(assistant)
            ? 'bg-n-teal-2 outline outline-1 outline-n-teal-6'
            : 'hover:bg-n-alpha-2'
        "
        @click="handleAssistantChange(assistant)"
      >
        <Avatar
          :name="assistant.name"
          :size="28"
          icon-name="i-lucide-bot"
          rounded-full
        />
        <span
          class="flex-1 text-sm font-medium truncate"
          :class="
            isAssistantActive(assistant) ? 'text-n-teal-12' : 'text-n-slate-12'
          "
        >
          {{ assistant.name || '' }}
        </span>
        <span
          v-if="isAssistantActive(assistant)"
          class="i-lucide-check size-4 shrink-0 text-n-teal-10"
        />
      </button>
    </div>
    <div v-else class="flex flex-col items-center gap-2 px-4 py-3">
      <p class="text-sm text-n-slate-11">
        {{ t('CAPTAIN.ASSISTANT_SWITCHER.EMPTY_LIST') }}
      </p>
    </div>
  </div>
</template>
