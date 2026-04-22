<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAccount } from 'dashboard/composables/useAccount';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

import CaptainAssistantTemplateAPI from 'dashboard/api/captain/assistantTemplate';

const emit = defineEmits(['close', 'created']);

const { t, locale: i18nLocale } = useI18n();
const store = useStore();
const { updateUISettings } = useUISettings();
const { currentAccount } = useAccount();

const dialogRef = ref(null);
const step = ref('template');
const templates = ref([]);
const selectedTemplate = ref(null);
const clarifyingQuestions = ref([]);
const clarifications = ref({});
const adaptedData = ref(null);
const isFetching = ref(false);
const isCreating = ref(false);

const resolvedLocale = computed(() =>
  i18nLocale.value?.startsWith('ru') ? 'ru' : 'en'
);

const industryIcons = {
  restaurant: 'i-lucide-utensils',
  beauty: 'i-lucide-scissors',
  hr: 'i-lucide-user-round-search',
  recruiter: 'i-lucide-user-round-search',
};

const templateIcon = template =>
  industryIcons[template.industry] || 'i-lucide-sparkles';

const loadTemplates = async () => {
  isFetching.value = true;
  try {
    const { data } = await CaptainAssistantTemplateAPI.list({
      locale: resolvedLocale.value,
    });
    templates.value = data;
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.ASSISTANTS.TEMPLATES.ERROR_MESSAGE'));
  } finally {
    isFetching.value = false;
  }
};

const loadClarifyingQuestions = async templateId => {
  isFetching.value = true;
  try {
    const { data } = await CaptainAssistantTemplateAPI.getClarifyingQuestions({
      templateId,
      locale: resolvedLocale.value,
    });
    clarifyingQuestions.value = data.questions || [];
    clarifications.value = {};
  } catch (error) {
    useAlert(error?.message || t('ERROR_MESSAGE'));
  } finally {
    isFetching.value = false;
  }
};

const transitionToCopilot = async assistant => {
  if (!assistant?.id) return;
  await store.dispatch('captainAssistants/get');
  await updateUISettings({
    preferred_captain_assistant_id: assistant.id,
    is_copilot_panel_open: true,
    is_contact_sidebar_open: false,
  });
};

const handleTemplateSelect = template => {
  selectedTemplate.value = template;
  step.value = 'clarifying';
  loadClarifyingQuestions(template.id);
};

const loadPreview = async () => {
  if (!selectedTemplate.value) return;
  isFetching.value = true;
  try {
    const { data } = await CaptainAssistantTemplateAPI.adapt({
      templateId: selectedTemplate.value.id,
      clarifications: clarifications.value,
      locale: resolvedLocale.value,
    });
    adaptedData.value = data;
    step.value = 'preview';
  } catch (error) {
    useAlert(error?.message || t('ERROR_MESSAGE'));
  } finally {
    isFetching.value = false;
  }
};

const handleCreateAssistant = async () => {
  if (!selectedTemplate.value || isCreating.value) return;
  isCreating.value = true;
  try {
    const assistant = await store.dispatch(
      'captainAssistantTemplates/createAssistant',
      {
        templateId: selectedTemplate.value.id,
        productName:
          selectedTemplate.value.product_name_placeholder ||
          currentAccount.value?.name ||
          selectedTemplate.value.name,
        locale: resolvedLocale.value,
        name: adaptedData.value?.assistant?.name,
        adapted_data: adaptedData.value,
      }
    );
    useAlert(t('CAPTAIN.ASSISTANTS.TEMPLATES.SUCCESS_MESSAGE'));
    await transitionToCopilot(assistant);
    emit('created', assistant);
    dialogRef.value.close();
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.ASSISTANTS.TEMPLATES.ERROR_MESSAGE'));
  } finally {
    isCreating.value = false;
  }
};

const handleClose = () => emit('close');

const open = () => {
  loadTemplates();
  step.value = 'template';
  selectedTemplate.value = null;
  clarifyingQuestions.value = [];
  clarifications.value = {};
  adaptedData.value = null;
  dialogRef.value.open();
};

defineExpose({ open, dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    width="3xl"
    :title="t('CAPTAIN.ASSISTANTS.TEMPLATES.TITLE')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    overflow-y-auto
    @close="handleClose"
  >
    <!-- Step 1: Template Selection -->
    <div v-if="step === 'template'" class="py-4">
      <p class="text-sm text-n-slate-11 mb-6">
        {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.DESCRIPTION') }}
      </p>

      <div
        v-if="isFetching"
        class="flex items-center justify-center py-10 text-n-slate-11"
      >
        <Spinner />
      </div>

      <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <button
          v-for="template in templates"
          :key="template.id"
          type="button"
          class="flex flex-col gap-2 p-4 text-start border border-n-weak rounded-xl bg-n-surface-1 hover:border-n-blue-9 hover:shadow transition-all disabled:opacity-60 disabled:cursor-not-allowed"
          @click="handleTemplateSelect(template)"
        >
          <div class="flex items-center gap-2">
            <Icon
              :icon="templateIcon(template)"
              class="size-5 text-n-blue-11"
            />
            <span class="text-sm font-medium text-n-slate-12">
              {{ template.name }}
            </span>
          </div>
          <p class="text-xs text-n-slate-11 line-clamp-3">
            {{ template.description }}
          </p>
          <div class="flex items-center gap-3 mt-1 text-xs text-n-slate-11">
            <span class="flex items-center gap-1">
              <Icon icon="i-lucide-workflow" class="size-3.5" />
              {{
                t('CAPTAIN.ASSISTANTS.TEMPLATES.SCENARIOS_COUNT', {
                  count: template.scenarios?.length || 0,
                })
              }}
            </span>
            <span class="flex items-center gap-1">
              <Icon icon="i-lucide-message-circle-question" class="size-3.5" />
              {{
                t('CAPTAIN.ASSISTANTS.TEMPLATES.FAQ_COUNT', {
                  count: template.faq_count || 0,
                })
              }}
            </span>
          </div>
        </button>
      </div>
    </div>

    <!-- Step 2: Clarifying Questions -->
    <div v-if="step === 'clarifying'" class="py-4">
      <button
        type="button"
        class="text-xs text-n-slate-11 hover:text-n-blue-11 mb-4 flex items-center gap-1"
        @click="step = 'template'"
      >
        <Icon icon="i-lucide-arrow-left" class="size-3" />
        {{ t('BACK') }}
      </button>

      <h3 class="text-lg font-medium text-n-slate-12 mb-4">
        {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.CLARIFYING_QUESTIONS_TITLE') }}
      </h3>

      <div
        v-if="isFetching"
        class="flex items-center justify-center py-10 text-n-slate-11"
      >
        <Spinner />
      </div>

      <div v-else-if="clarifyingQuestions.length" class="space-y-4">
        <div
          v-for="question in clarifyingQuestions"
          :key="question.purpose"
          class="space-y-2"
        >
          <label class="block text-sm font-medium text-n-slate-12">
            {{ question.question }}
          </label>
          <textarea
            v-model="clarifications[question.purpose]"
            rows="2"
            class="w-full px-3 py-2 text-sm border border-n-weak rounded-lg bg-n-surface-1 resize-none focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand"
            :placeholder="t('YOUR_ANSWER')"
          />
        </div>
      </div>

      <div v-else class="text-sm text-n-slate-11">
        {{ t('NO_ADDITIONAL_INFORMATION_NEEDED') }}
      </div>

      <div class="mt-6 flex justify-end">
        <button
          type="button"
          class="px-4 py-2 bg-n-blue-6 text-white rounded-lg text-sm font-medium hover:bg-n-blue-7 transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
          :disabled="isFetching"
          @click="loadPreview"
        >
          {{ t('CONTINUE') }}
        </button>
      </div>
    </div>

    <!-- Step 3: Preview -->
    <div v-if="step === 'preview'" class="py-4">
      <button
        type="button"
        class="text-xs text-n-slate-11 hover:text-n-blue-11 mb-4 flex items-center gap-1"
        @click="step = 'clarifying'"
      >
        <Icon icon="i-lucide-arrow-left" class="size-3" />
        {{ t('BACK') }}
      </button>

      <h3 class="text-lg font-medium text-n-slate-12 mb-4">
        {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.PREVIEW_TITLE') }}
      </h3>

      <div
        v-if="isFetching"
        class="flex items-center justify-center py-10 text-n-slate-11"
      >
        <Spinner />
      </div>

      <div v-else-if="adaptedData" class="space-y-6">
        <!-- Assistant Info -->
        <div class="p-4 border border-n-weak rounded-lg bg-n-surface-1">
          <h4 class="text-sm font-medium text-n-slate-12 mb-3">
            {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.PREVIEW_ASSISTANT') }}
          </h4>
          <div class="space-y-2">
            <div>
              <label class="text-xs text-n-slate-10 uppercase font-medium">
                {{ t('NAME') }}
              </label>
              <p class="text-sm text-n-slate-12 mt-1">
                {{ adaptedData.assistant.name }}
              </p>
            </div>
            <div>
              <label class="text-xs text-n-slate-10 uppercase font-medium">
                {{ t('DESCRIPTION') }}
              </label>
              <p class="text-sm text-n-slate-11 mt-1">
                {{ adaptedData.assistant.description }}
              </p>
            </div>
          </div>
        </div>

        <!-- Scenarios -->
        <div class="p-4 border border-n-weak rounded-lg bg-n-surface-1">
          <h4 class="text-sm font-medium text-n-slate-12 mb-3">
            {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.PREVIEW_SCENARIOS') }}
          </h4>
          <div class="space-y-3">
            <div
              v-for="scenario in adaptedData.scenarios"
              :key="scenario.title"
              class="p-3 border border-n-weak rounded-lg"
            >
              <div class="flex items-start gap-2">
                <Icon
                  icon="i-lucide-workflow"
                  class="size-4 text-n-slate-10 mt-0.5 flex-shrink-0"
                />
                <div>
                  <p class="text-sm font-medium text-n-slate-12">
                    {{ scenario.title }}
                  </p>
                  <p class="text-xs text-n-slate-11 mt-1">
                    {{ scenario.description }}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- FAQ Count -->
        <div class="p-4 border border-n-weak rounded-lg bg-n-surface-1">
          <div class="flex items-center gap-3">
            <div class="p-2 bg-n-blue-5 rounded-lg">
              <Icon
                icon="i-lucide-message-circle-question"
                class="size-5 text-n-blue-11"
              />
            </div>
            <div>
              <p class="text-sm font-medium text-n-slate-12">
                {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.PREVIEW_FAQ') }}
              </p>
              <p class="text-xs text-n-slate-11">
                {{
                  t('CAPTAIN.ASSISTANTS.TEMPLATES.PREVIEW_FAQ_COUNT', {
                    count: adaptedData.faq_seed.length,
                  })
                }}
              </p>
            </div>
          </div>
        </div>

        <!-- Note about adaptation -->
        <div
          class="p-3 bg-n-brand/5 dark:bg-n-brand/10 rounded-lg border border-n-brand/10"
        >
          <div class="flex items-start gap-2">
            <Icon
              icon="i-lucide-info"
              class="size-4 text-n-brand mt-0.5 flex-shrink-0"
            />
            <p class="text-xs text-n-slate-11">
              {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.PREVIEW_ADAPTATION_NOTE') }}
            </p>
          </div>
        </div>
      </div>

      <div v-else class="text-sm text-n-slate-11 text-center py-8">
        {{ t('ERROR_MESSAGE') }}
      </div>

      <div class="mt-6 flex justify-end gap-3">
        <button
          type="button"
          class="px-4 py-2 bg-n-slate-2 text-n-slate-12 rounded-lg text-sm font-medium hover:bg-n-slate-3 transition-colors"
          :disabled="isFetching"
          @click="step = 'clarifying'"
        >
          {{ t('EDIT') }}
        </button>
        <button
          type="button"
          class="px-4 py-2 bg-n-blue-6 text-white rounded-lg text-sm font-medium hover:bg-n-blue-7 transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
          :disabled="isFetching || isCreating"
          @click="handleCreateAssistant"
        >
          <Spinner v-if="isCreating" class="size-4 ltr:mr-2 rtl:ml-2" />
          {{ t('CREATE_ASSISTANT') }}
        </button>
      </div>
    </div>
  </Dialog>
</template>
