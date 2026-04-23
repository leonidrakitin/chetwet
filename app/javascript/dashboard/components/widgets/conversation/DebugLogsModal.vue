<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useTrack } from 'dashboard/composables';
import { COPILOT_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import axios from 'axios';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  copilotThreadId: {
    type: [Number, String],
    default: null,
  },
  currentChat: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['cancel']);

const { t } = useI18n();
const debugData = ref(null);
const isLoading = ref(false);

const localShow = computed({
  get() {
    return props.show;
  },
  set(value) {
    emit('cancel', value);
  },
});

const loadDebugData = async () => {
  if (!props.copilotThreadId) {
    useAlert(t('DEBUG_LOGS.NO_LOGS_FOUND'));
    return;
  }

  isLoading.value = true;
  try {
    const response = await axios.get(
      `/api/v1/accounts/${props.currentChat.account_id}/captain/copilot_debug/${props.copilotThreadId}`
    );
    debugData.value = response.data;
    useTrack(COPILOT_EVENTS.DEBUG_LOGS_OPENED);
  } catch (error) {
    useAlert(t('DEBUG_LOGS.ERROR_LOADING'));
  } finally {
    isLoading.value = false;
  }
};

watch(
  () => props.show,
  newValue => {
    if (newValue && props.copilotThreadId) {
      loadDebugData();
    }
  }
);

const formatDate = dateString => {
  if (!dateString) return '';
  return new Date(dateString).toLocaleString();
};

const getFriendlyToolName = toolName => {
  const toolNames = {
    'Captain::Tools::SearchDocumentationService': t(
      'DEBUG_LOGS.TOOLS.DOCUMENTATION'
    ),
    'Captain::Tools::Copilot::GetConversationService': t(
      'DEBUG_LOGS.TOOLS.CONVERSATION'
    ),
    'Captain::Tools::Copilot::SearchConversationsService': t(
      'DEBUG_LOGS.TOOLS.SEARCH_CONVERSATIONS'
    ),
    'Captain::Tools::Copilot::GetContactService': t('DEBUG_LOGS.TOOLS.CONTACT'),
    'Captain::Tools::Copilot::GetArticleService': t('DEBUG_LOGS.TOOLS.ARTICLE'),
    'Captain::Tools::Copilot::SearchArticlesService': t(
      'DEBUG_LOGS.TOOLS.SEARCH_ARTICLES'
    ),
    'Captain::Tools::Copilot::SearchContactsService': t(
      'DEBUG_LOGS.TOOLS.SEARCH_CONTACTS'
    ),
    'Captain::Tools::Copilot::SearchLinearIssuesService': t(
      'DEBUG_LOGS.TOOLS.LINEAR_ISSUES'
    ),
    'Captain::Tools::Copilot::ConfigureAssistantService': t(
      'DEBUG_LOGS.TOOLS.CONFIGURE_ASSISTANT'
    ),
    'Captain::Tools::Copilot::SuggestFaqsService': t(
      'DEBUG_LOGS.TOOLS.SUGGEST_FAQS'
    ),
    'Captain::Tools::Copilot::AdaptFaqService': t('DEBUG_LOGS.TOOLS.ADAPT_FAQ'),
    'Captain::Tools::Copilot::AdaptScenarioService': t(
      'DEBUG_LOGS.TOOLS.ADAPT_SCENARIO'
    ),
    'Captain::Tools::Copilot::ListNotificationTemplatesService': t(
      'DEBUG_LOGS.TOOLS.LIST_NOTIFICATION_TEMPLATES'
    ),
    'Captain::Tools::Copilot::GetNotificationTemplateService': t(
      'DEBUG_LOGS.TOOLS.GET_NOTIFICATION_TEMPLATE'
    ),
    'Captain::Tools::Copilot::CreateNotificationTemplateService': t(
      'DEBUG_LOGS.TOOLS.CREATE_NOTIFICATION_TEMPLATE'
    ),
    'Captain::Tools::Copilot::UpdateNotificationTemplateService': t(
      'DEBUG_LOGS.TOOLS.UPDATE_NOTIFICATION_TEMPLATE'
    ),
    'Captain::Tools::Copilot::DeleteNotificationTemplateService': t(
      'DEBUG_LOGS.TOOLS.DELETE_NOTIFICATION_TEMPLATE'
    ),
    'Captain::Tools::Copilot::CreateSegmentService': t(
      'DEBUG_LOGS.TOOLS.CREATE_SEGMENT'
    ),
  };
  return toolNames[toolName] || toolName;
};

const isMessageFromUser = msg => msg.message_type === 'user';
const isMessageFromAssistant = msg => msg.message_type === 'assistant';
const isThinkingMessage = msg => msg.message_type === 'assistant_thinking';
</script>

<template>
  <woot-modal
    v-model:show="localShow"
    size="modal-big"
    :on-close="() => emit('cancel', false)"
  >
    <div class="flex flex-col h-auto overflow-auto bg-purple-50">
      <div
        class="flex items-center justify-between px-6 py-4 bg-purple-100 border-b border-purple-200"
      >
        <div class="flex items-center gap-3">
          <Icon icon="i-lucide-terminal" class="w-6 h-6 text-purple-700" />
          <h3 class="text-lg font-semibold text-purple-900">
            {{ t('DEBUG_LOGS.TITLE') }}
          </h3>
        </div>
        <Icon
          icon="i-lucide-x"
          class="w-5 h-5 text-purple-600 cursor-pointer"
          @click="() => emit('cancel', false)"
        />
      </div>

      <div v-if="isLoading" class="flex items-center justify-center py-12">
        <Icon
          icon="i-lucide-loader-2"
          class="w-6 h-6 text-purple-700 animate-spin"
        />
        <span class="ml-2 text-purple-800">{{ t('DEBUG_LOGS.LOADING') }}</span>
      </div>

      <div v-else-if="!debugData" class="px-6 py-8">
        <div class="text-center">
          <Icon
            icon="i-lucide-alert-circle"
            class="w-12 h-12 mx-auto text-purple-300"
          />
          <p class="mt-2 text-purple-800">
            {{ t('DEBUG_LOGS.NO_LOGS_FOUND') }}
          </p>
        </div>
      </div>

      <div v-else class="flex-1 overflow-y-auto p-6 space-y-6">
        <div class="bg-white rounded-lg shadow-sm border border-purple-100 p-4">
          <h4 class="text-sm font-semibold text-purple-800 mb-3">
            {{ t('DEBUG_LOGS.CONVERSATION_INFO') }}
          </h4>
          <div class="grid grid-cols-2 gap-3 text-sm">
            <div>
              <span class="text-gray-500 block text-xs">{{
                t('DEBUG_LOGS.CONVERSATION_ID')
              }}</span>
              <span class="font-medium text-gray-900">{{
                debugData.conversation?.id
              }}</span>
            </div>
            <div>
              <span class="text-gray-500 block text-xs">{{
                t('DEBUG_LOGS.THREAD_ID')
              }}</span>
              <span class="font-medium text-gray-900">{{
                debugData.thread.id
              }}</span>
            </div>
            <div>
              <span class="text-gray-500 block text-xs">{{
                t('DEBUG_LOGS.CREATED_AT')
              }}</span>
              <span class="font-medium text-gray-900">{{
                formatDate(debugData.thread.created_at)
              }}</span>
            </div>
            <div>
              <span class="text-gray-500 block text-xs">{{
                t('DEBUG_LOGS.TITLE')
              }}</span>
              <span class="font-medium text-gray-900">{{
                debugData.thread.title
              }}</span>
            </div>
          </div>
        </div>

        <div
          v-if="debugData.messages && debugData.messages.length"
          class="space-y-4"
        >
          <h4 class="text-sm font-semibold text-purple-800">
            {{ t('DEBUG_LOGS.MESSAGES') }}
          </h4>
          <div class="space-y-4">
            <div
              v-for="message in debugData.messages"
              :key="message.id"
              class="bg-white rounded-lg shadow-sm border border-purple-100 p-4"
            >
              <div class="flex items-center justify-between mb-3">
                <div class="flex items-center gap-2">
                  <Icon
                    :icon="
                      isMessageFromUser(message)
                        ? 'i-lucide-user'
                        : isMessageFromAssistant(message)
                          ? 'i-lucide-robot'
                          : 'i-lucide-sparkles'
                    "
                    class="w-4 h-4"
                    :class="{
                      'text-purple-700': isMessageFromUser(message),
                      'text-cyan-700': isMessageFromAssistant(message),
                      'text-amber-600': isThinkingMessage(message),
                    }"
                  />
                  <span
                    class="text-xs font-medium uppercase"
                    :class="{
                      'text-purple-700': isMessageFromUser(message),
                      'text-cyan-700': isMessageFromAssistant(message),
                      'text-amber-600': isThinkingMessage(message),
                    }"
                  >
                    {{
                      isMessageFromUser(message)
                        ? t('DEBUG_LOGS.USER')
                        : isMessageFromAssistant(message)
                          ? t('DEBUG_LOGS.ASSISTANT')
                          : t('DEBUG_LOGS.THINKING')
                    }}
                  </span>
                </div>
                <span class="text-xs text-gray-400">{{
                  formatDate(message.created_at)
                }}</span>
              </div>

              <div v-if="message.message?.content" class="mb-2">
                <p class="text-sm text-gray-700 whitespace-pre-wrap">
                  {{ message.message.content }}
                </p>
              </div>

              <div v-if="message.reasoning" class="mb-2">
                <button
                  class="flex items-center gap-1 text-xs text-purple-700 hover:text-purple-900 transition-colors"
                >
                  <Icon icon="i-lucide-chevron-down" class="w-3 h-3" />
                  {{ t('DEBUG_LOGS.REASONING') }}
                </button>
                <div
                  class="mt-2 p-2 bg-purple-50 rounded border border-purple-100"
                >
                  <p class="text-xs text-gray-700 whitespace-pre-wrap">
                    {{ message.reasoning }}
                  </p>
                </div>
              </div>

              <div
                v-if="message.message?.function_name"
                class="flex items-center gap-2"
              >
                <Icon icon="i-lucide-wrench" class="w-3 h-3 text-purple-700" />
                <span class="text-xs text-gray-600">{{
                  getFriendlyToolName(message.message.function_name)
                }}</span>
              </div>
            </div>
          </div>
        </div>

        <div
          v-if="debugData.tools_used && debugData.tools_used.length"
          class="bg-white rounded-lg shadow-sm border border-purple-100 p-4"
        >
          <h4 class="text-sm font-semibold text-purple-800 mb-3">
            {{ t('DEBUG_LOGS.TOOLS_USED') }}
          </h4>
          <div class="flex flex-wrap gap-2">
            <span
              v-for="tool in debugData.tools_used"
              :key="tool"
              class="px-3 py-1 text-xs font-medium rounded-full bg-purple-100 text-purple-800"
            >
              {{ tool }}
            </span>
          </div>
        </div>

        <div
          v-if="
            debugData.notification_templates &&
            debugData.notification_templates.length
          "
          class="bg-white rounded-lg shadow-sm border border-purple-100 p-4"
        >
          <h4 class="text-sm font-semibold text-purple-800 mb-3">
            {{ t('DEBUG_LOGS.NOTIFICATION_TEMPLATES') }}
          </h4>
          <ul class="list-disc list-inside text-sm text-gray-600 space-y-1">
            <li
              v-for="template in debugData.notification_templates"
              :key="template.name"
            >
              {{ template.name }}
            </li>
          </ul>
        </div>
      </div>

      <div
        class="flex justify-end px-6 py-4 bg-purple-50 border-t border-purple-100"
      >
        <Button
          :label="t('DEBUG_LOGS.CLOSE')"
          @click="() => emit('cancel', false)"
        />
      </div>
    </div>
  </woot-modal>
</template>
