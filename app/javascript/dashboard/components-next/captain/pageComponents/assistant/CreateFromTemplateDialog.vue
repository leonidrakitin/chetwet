<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAccount } from 'dashboard/composables/useAccount';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const emit = defineEmits(['close', 'created']);

const { t, locale: i18nLocale } = useI18n();
const store = useStore();
const { updateUISettings } = useUISettings();
const { currentAccount } = useAccount();

const dialogRef = ref(null);
const creatingKey = ref(null);

const templates = useMapGetter('captainAssistantTemplates/getRecords');
const templateUiFlags = useMapGetter('captainAssistantTemplates/getUIFlags');
const assistantUiFlags = useMapGetter('captainAssistants/getUIFlags');

const isFetching = computed(() => templateUiFlags.value.fetchingList);
const isCreating = computed(
  () =>
    templateUiFlags.value.creatingAssistant ||
    assistantUiFlags.value.creatingItem
);

const industryIcons = {
  restaurant: 'i-lucide-utensils',
  beauty: 'i-lucide-scissors',
  hr: 'i-lucide-user-round-search',
  recruiter: 'i-lucide-user-round-search',
};

const templateIcon = template =>
  industryIcons[template.industry] || 'i-lucide-sparkles';

const resolvedLocale = computed(() =>
  i18nLocale.value?.startsWith('ru') ? 'ru' : 'en'
);

const loadTemplates = () => {
  store.dispatch('captainAssistantTemplates/list', {
    locale: resolvedLocale.value,
  });
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

const handleCreateFromTemplate = async template => {
  if (isCreating.value) return;
  creatingKey.value = template.id;
  try {
    const assistant = await store.dispatch(
      'captainAssistantTemplates/createAssistant',
      {
        templateId: template.id,
        productName:
          template.product_name_placeholder ||
          currentAccount.value?.name ||
          template.name,
        locale: resolvedLocale.value,
      }
    );
    useAlert(t('CAPTAIN.ASSISTANTS.TEMPLATES.SUCCESS_MESSAGE'));
    await transitionToCopilot(assistant);
    emit('created', assistant);
    dialogRef.value.close();
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.ASSISTANTS.TEMPLATES.ERROR_MESSAGE'));
  } finally {
    creatingKey.value = null;
  }
};

const handleCreateEmpty = async () => {
  if (isCreating.value) return;
  creatingKey.value = 'empty';
  try {
    const defaultName = t('CAPTAIN.ASSISTANTS.TEMPLATES.EMPTY.DEFAULT_NAME');
    const productName = currentAccount.value?.name || defaultName;
    const assistant = await store.dispatch('captainAssistants/create', {
      name: defaultName,
      description: t('CAPTAIN.ASSISTANTS.TEMPLATES.EMPTY.DEFAULT_DESCRIPTION'),
      config: {
        product_name: productName,
        feature_faq: false,
        feature_memory: false,
        feature_citation: false,
      },
    });
    useAlert(t('CAPTAIN.ASSISTANTS.CREATE.SUCCESS_MESSAGE'));
    await transitionToCopilot(assistant);
    emit('created', assistant);
    dialogRef.value.close();
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.ASSISTANTS.CREATE.ERROR_MESSAGE'));
  } finally {
    creatingKey.value = null;
  }
};

const handleClose = () => emit('close');

const open = () => {
  loadTemplates();
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
    :description="t('CAPTAIN.ASSISTANTS.TEMPLATES.DESCRIPTION')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    overflow-y-auto
    @close="handleClose"
  >
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
        :disabled="isCreating"
        @click="handleCreateFromTemplate(template)"
      >
        <div class="flex items-center gap-2">
          <Icon :icon="templateIcon(template)" class="size-5 text-n-blue-11" />
          <span class="text-sm font-medium text-n-slate-12">
            {{ template.name }}
          </span>
          <Spinner
            v-if="creatingKey === template.id"
            class="ltr:ml-auto rtl:mr-auto size-4"
          />
        </div>
        <p class="text-xs text-n-slate-11 line-clamp-3">
          {{ template.description }}
        </p>
        <div class="flex items-center gap-3 mt-1 text-xs text-n-slate-11">
          <span class="flex items-center gap-1">
            <Icon icon="i-lucide-workflow" class="size-3.5" />
            {{
              t('CAPTAIN.ASSISTANTS.TEMPLATES.SCENARIOS_COUNT', {
                count: template.scenarios.length,
              })
            }}
          </span>
          <span class="flex items-center gap-1">
            <Icon icon="i-lucide-message-circle-question" class="size-3.5" />
            {{
              t('CAPTAIN.ASSISTANTS.TEMPLATES.FAQ_COUNT', {
                count: template.faq_count,
              })
            }}
          </span>
        </div>
      </button>

      <button
        type="button"
        class="flex flex-col gap-2 p-4 text-start border border-dashed border-n-weak rounded-xl bg-n-alpha-1 hover:border-n-blue-9 hover:bg-n-alpha-2 transition-all disabled:opacity-60 disabled:cursor-not-allowed"
        :disabled="isCreating"
        @click="handleCreateEmpty"
      >
        <div class="flex items-center gap-2">
          <Icon icon="i-lucide-plus" class="size-5 text-n-blue-11" />
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.EMPTY.TITLE') }}
          </span>
          <Spinner
            v-if="creatingKey === 'empty'"
            class="ltr:ml-auto rtl:mr-auto size-4"
          />
        </div>
        <p class="text-xs text-n-slate-11 line-clamp-3">
          {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.EMPTY.DESCRIPTION') }}
        </p>
      </button>
    </div>

    <template #footer />
  </Dialog>
</template>
