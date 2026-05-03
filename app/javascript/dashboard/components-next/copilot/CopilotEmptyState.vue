<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import Icon from '../icon/Icon.vue';
import ConfigureAssistantFromTemplate from './ConfigureAssistantFromTemplate.vue';

defineProps({
  hasAssistants: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['useSuggestion', 'createAssistant']);
const { t } = useI18n();
const route = useRoute();

const configureAssistantDialogRef = ref(null);

const routePromptMap = {
  conversations: [
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.SUMMARIZE.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.SUMMARIZE.CONTENT',
    },
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.SUGGEST.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.SUGGEST.CONTENT',
    },
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.RATE.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.RATE.CONTENT',
    },
  ],
  dashboard: [
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.HIGH_PRIORITY.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.HIGH_PRIORITY.CONTENT',
    },
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.LIST_CONTACTS.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.LIST_CONTACTS.CONTENT',
    },
  ],
  notification: [
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.LIST_TEMPLATES.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.LIST_TEMPLATES.CONTENT',
    },
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.CREATE_TEMPLATE.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.CREATE_TEMPLATE.CONTENT',
    },
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.FIND_TEMPLATE.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.FIND_TEMPLATE.CONTENT',
    },
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.REVIEW_TEMPLATES.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.REVIEW_TEMPLATES.CONTENT',
    },
  ],
  contacts: [
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.SEARCH_CONTACTS.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.SEARCH_CONTACTS.CONTENT',
    },
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.RECENT_CONTACTS.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.RECENT_CONTACTS.CONTENT',
    },
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.CONTACT_CONVERSATIONS.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.CONTACT_CONVERSATIONS.CONTENT',
    },
  ],
  reports: [
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.OPEN_CONVERSATIONS.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.OPEN_CONVERSATIONS.CONTENT',
    },
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.AGENT_PERFORMANCE.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.AGENT_PERFORMANCE.CONTENT',
    },
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.UNRESOLVED_HIGH_PRIORITY.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.UNRESOLVED_HIGH_PRIORITY.CONTENT',
    },
  ],
  settings: [
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.SEARCH_HELP.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.SEARCH_HELP.CONTENT',
    },
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.INBOX_OVERVIEW.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.INBOX_OVERVIEW.CONTENT',
    },
  ],
  captain: [
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.LIST_ASSISTANTS.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.LIST_ASSISTANTS.CONTENT',
    },
    {
      label: 'CAPTAIN.COPILOT.PROMPTS.SEARCH_KNOWLEDGE.LABEL',
      prompt: 'CAPTAIN.COPILOT.PROMPTS.SEARCH_KNOWLEDGE.CONTENT',
    },
  ],
};

const getCurrentRoute = () => {
  const path = route.path;
  if (path.includes('/conversations')) return 'conversations';
  if (path.includes('/notification')) return 'notification';
  if (path.includes('/contacts')) return 'contacts';
  if (path.includes('/reports')) return 'reports';
  if (path.includes('/captain')) return 'captain';
  if (path.includes('/settings')) return 'settings';
  if (path.includes('/dashboard')) return 'dashboard';
  return 'dashboard';
};

const promptOptions = computed(() => {
  const currentRoute = getCurrentRoute();
  return routePromptMap[currentRoute] || routePromptMap.dashboard;
});

const handleSuggestion = opt => {
  emit('useSuggestion', t(opt.prompt));
};

const handleCreated = assistant => {
  emit('createAssistant', assistant);
};
</script>

<template>
  <div class="flex-1 flex flex-col gap-6 px-2">
    <div class="flex flex-col space-y-4 py-4">
      <Icon icon="i-woot-captain" class="text-n-slate-9 text-4xl" />
      <div class="space-y-1">
        <h3 class="text-base font-medium text-n-text-display leading-8">
          {{ $t('CAPTAIN.COPILOT.PANEL_TITLE') }}
        </h3>
        <p class="text-sm text-n-text-body leading-6">
          {{ $t('CAPTAIN.COPILOT.KICK_OFF_MESSAGE') }}
        </p>
      </div>
    </div>
    <div v-if="!hasAssistants" class="w-full space-y-2">
      <p class="text-sm text-n-text-body leading-6">
        {{ $t('CAPTAIN.ASSISTANTS.NO_ASSISTANTS_AVAILABLE') }}
      </p>
      <div class="flex flex-col gap-2">
        <button
          type="button"
          class="w-full px-3 py-2 rounded-md border border-n-blue-9 bg-n-blue-6 text-white hover:bg-n-blue-7 transition-colors text-sm font-medium"
          @click="configureAssistantDialogRef?.open()"
        >
          {{ $t('CAPTAIN.ASSISTANTS.ADD_NEW') }}
        </button>
        <router-link
          :to="{
            name: 'captain_assistants_create_index',
            params: {
              accountId: route.params.accountId,
            },
          }"
          class="text-n-text-body underline hover:text-n-text-display text-sm"
        >
          {{ $t('CAPTAIN.ASSISTANTS.CREATE_EMPTY') }}
        </router-link>
      </div>
    </div>
    <div v-else class="w-full space-y-2">
      <span class="text-xs text-n-text-body/60 block">
        {{ $t('CAPTAIN.COPILOT.TRY_THESE_PROMPTS') }}
      </span>
      <div class="space-y-1">
        <button
          v-for="prompt in promptOptions"
          :key="prompt.label"
          class="w-full px-3 py-2 rounded-md border border-n-border-glass-soft bg-n-slate-2 text-n-text-body flex items-center justify-between hover:bg-n-slate-3 transition-colors"
          @click="handleSuggestion(prompt)"
        >
          <span>{{ t(prompt.label) }}</span>
          <Icon icon="i-lucide-chevron-right" />
        </button>
      </div>
    </div>

    <ConfigureAssistantFromTemplate
      ref="configureAssistantDialogRef"
      @created="handleCreated"
    />
  </div>
</template>
