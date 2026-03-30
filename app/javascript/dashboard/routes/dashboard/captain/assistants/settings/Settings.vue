<script setup>
import { computed, onMounted, watch, ref, nextTick } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { storeToRefs } from 'pinia';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';
import { useCaptainConfigStore } from 'dashboard/store/captain/preferences';
import CaptainAssistantAPI from 'dashboard/api/captain/assistant';
import Button from 'dashboard/components-next/button/Button.vue';
import Policy from 'dashboard/components/policy.vue';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import AssistantBasicSettingsForm from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantBasicSettingsForm.vue';
import AssistantSystemSettingsForm from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantSystemSettingsForm.vue';
import AssistantControlItems from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantControlItems.vue';
import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';
import ToolCategorySection from 'dashboard/components-next/captain/pageComponents/customTool/ToolCategorySection.vue';
import CreateCustomToolDialog from 'dashboard/components-next/captain/pageComponents/customTool/CreateCustomToolDialog.vue';
import InboxCard from 'dashboard/components-next/captain/assistant/InboxCard.vue';
import ConnectInboxDialog from 'dashboard/components-next/captain/pageComponents/inbox/ConnectInboxDialog.vue';

const ICON_MAP = {
  'note-add': 'i-lucide-notebook-pen',
  'eye-off': 'i-lucide-eye-off',
  'exclamation-triangle': 'i-lucide-triangle-alert',
  tag: 'i-lucide-tag',
  search: 'i-lucide-search',
  checkmark: 'i-lucide-check',
  'checkmark-circle': 'i-lucide-circle-check',
  'user-switch': 'i-lucide-user-round-cog',
  calendar: 'i-lucide-calendar',
  clock: 'i-lucide-clock',
  list: 'i-lucide-list',
  currency: 'i-lucide-banknote',
  'shopping-bag': 'i-lucide-shopping-bag',
};

const BUILT_IN_CATEGORY_ORDER = ['core', 'vk_market', 'yclients'];
const CAPTAIN_FEATURE_ICON_MAP = {
  label_suggestion: 'i-lucide-tag',
  help_center_search: 'i-lucide-search',
  audio_transcription: 'i-lucide-audio-lines',
};
const BUILT_IN_CATEGORY_SECTION_META = {
  core: {
    icon: 'i-lucide-blocks',
    iconColor: 'text-n-blue-11',
    bgColor: 'bg-n-blue-3',
  },
  vk_market: {
    icon: 'i-lucide-shopping-bag',
    iconColor: 'text-n-violet-11',
    bgColor: 'bg-n-violet-3',
  },
  yclients: {
    icon: 'i-lucide-calendar',
    iconColor: 'text-n-teal-11',
    bgColor: 'bg-n-teal-3',
  },
};

const { t, te } = useI18n();
const { isCloudFeatureEnabled } = useAccount();
const isCaptainV2Enabled = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.CAPTAIN_V2)
);
const isHelpCenterEnabled = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.HELP_CENTER)
);

const route = useRoute();
const router = useRouter();
const store = useStore();

// ── Assistant ──────────────────────────────────────────────────────────────
const deleteAssistantDialog = ref(null);
const uiFlags = useMapGetter('captainAssistants/getUIFlags');
const assistants = useMapGetter('captainAssistants/getRecords');
const isFetching = computed(() => uiFlags.value.fetchingItem);
const assistantId = computed(() => Number(route.params.assistantId));
const assistant = computed(() =>
  store.getters['captainAssistants/getRecord'](assistantId.value)
);

// ── Inboxes ────────────────────────────────────────────────────────────────
const captainInboxes = useMapGetter('captainInboxes/getRecords');
const inboxDialogType = ref('');
const selectedInbox = ref(null);
const connectInboxDialog = ref(null);
const disconnectInboxDialog = ref(null);

watch(
  assistantId,
  newId => store.dispatch('captainInboxes/get', { assistantId: newId }),
  { immediate: true }
);

const handleInboxCreate = () => {
  inboxDialogType.value = 'create';
  nextTick(() => connectInboxDialog.value.dialogRef.open());
};
const handleInboxAction = ({ action, id }) => {
  selectedInbox.value = captainInboxes.value.find(inbox => id === inbox.id);
  nextTick(() => {
    if (action === 'delete') disconnectInboxDialog.value.dialogRef.open();
  });
};
const handleInboxCreateClose = () => {
  inboxDialogType.value = '';
  selectedInbox.value = null;
};

// ── Tools ──────────────────────────────────────────────────────────────────
const captainConfigStore = useCaptainConfigStore();
const { features: captainFeatures } = storeToRefs(captainConfigStore);
const customTools = useMapGetter('captainCustomTools/getRecords');
const customToolsMeta = useMapGetter('captainCustomTools/getMeta');

const toolDialogType = ref('');
const selectedTool = ref(null);
const createToolDialogRef = ref(null);
const deleteToolDialogRef = ref(null);
const toolStateOverrides = ref({});
const savingToggleIds = ref([]);
const builtInTools = ref([]);

const capabilities = computed(() => {
  const config = assistant.value?.config || {};
  return [
    {
      id: 'feature_faq',
      title: t('CAPTAIN.ASSISTANTS.FORM.FEATURES.ALLOW_CONVERSATION_FAQS'),
      icon: 'i-lucide-help-circle',
      enabled:
        toolStateOverrides.value.feature_faq ?? config.feature_faq ?? false,
    },
    {
      id: 'feature_memory',
      title: t('CAPTAIN.ASSISTANTS.FORM.FEATURES.ALLOW_MEMORIES'),
      icon: 'i-lucide-brain',
      enabled:
        toolStateOverrides.value.feature_memory ??
        config.feature_memory ??
        false,
    },
    {
      id: 'feature_citation',
      title: t('CAPTAIN.ASSISTANTS.FORM.FEATURES.ALLOW_CITATIONS'),
      icon: 'i-lucide-quote',
      enabled:
        toolStateOverrides.value.feature_citation ??
        config.feature_citation ??
        false,
    },
    {
      id: 'feature_contact_attributes',
      title: t('CAPTAIN.ASSISTANTS.FORM.FEATURES.ALLOW_CONTACT_ATTRIBUTES'),
      icon: 'i-lucide-user',
      enabled:
        toolStateOverrides.value.feature_contact_attributes ??
        config.feature_contact_attributes ??
        false,
    },
  ];
});

const captainFeatureCapabilities = computed(() => {
  const featureKeys = [
    'label_suggestion',
    ...(isHelpCenterEnabled.value ? ['help_center_search'] : []),
    'audio_transcription',
  ];
  return featureKeys
    .filter(key => captainFeatures.value?.[key] !== undefined)
    .map(key => ({
      id: key,
      title: t(`CAPTAIN_SETTINGS.FEATURES.${key.toUpperCase()}.TITLE`),
      description: t(
        `CAPTAIN_SETTINGS.FEATURES.${key.toUpperCase()}.DESCRIPTION`
      ),
      icon: CAPTAIN_FEATURE_ICON_MAP[key] || 'i-lucide-bot',
      enabled:
        toolStateOverrides.value[key] ?? !!captainFeatures.value[key]?.enabled,
    }));
});

const builtInToolRows = computed(() =>
  builtInTools.value.map(tool => {
    const titleKey = `CAPTAIN.BUILT_IN_TOOLS.TOOLS.${tool.id}.TITLE`;
    const descKey = `CAPTAIN.BUILT_IN_TOOLS.TOOLS.${tool.id}.DESCRIPTION`;
    return {
      ...tool,
      title: te(titleKey) ? t(titleKey) : tool.title,
      description: te(descKey) ? t(descKey) : tool.description,
      icon: ICON_MAP[tool.icon] || 'i-lucide-wrench',
      category: tool.category || 'core',
    };
  })
);

const builtInCategorySections = computed(() => {
  const byCat = new Map();
  builtInToolRows.value.forEach(item => {
    const cat = item.category || 'core';
    if (!byCat.has(cat)) byCat.set(cat, []);
    byCat.get(cat).push(item);
  });
  const tailKeys = [...byCat.keys()]
    .filter(k => !BUILT_IN_CATEGORY_ORDER.includes(k))
    .sort();
  const orderedKeys = [
    ...BUILT_IN_CATEGORY_ORDER.filter(k => byCat.has(k)),
    ...tailKeys,
  ];
  return orderedKeys.map(key => {
    const meta =
      BUILT_IN_CATEGORY_SECTION_META[key] ||
      BUILT_IN_CATEGORY_SECTION_META.core;
    const titleKey = `CAPTAIN.BUILT_IN_TOOLS.CATEGORIES.${key}.TITLE`;
    const descKey = `CAPTAIN.BUILT_IN_TOOLS.CATEGORIES.${key}.DESCRIPTION`;
    return {
      key,
      items: byCat.get(key),
      title: te(titleKey) ? t(titleKey) : key,
      description: te(descKey) ? t(descKey) : '',
      ...meta,
    };
  });
});

const customToolItems = computed(() =>
  customTools.value.map(tool => ({
    ...tool,
    icon: 'i-lucide-wrench',
    enabled: true,
  }))
);

const controlItems = computed(() => [
  {
    name: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONTROL_ITEMS.OPTIONS.GUARDRAILS.TITLE'
    ),
    description: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONTROL_ITEMS.OPTIONS.GUARDRAILS.DESCRIPTION'
    ),
    routeName: 'captain_assistants_guardrails_index',
  },
  {
    name: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONTROL_ITEMS.OPTIONS.RESPONSE_GUIDELINES.TITLE'
    ),
    description: t(
      'CAPTAIN.ASSISTANTS.SETTINGS.CONTROL_ITEMS.OPTIONS.RESPONSE_GUIDELINES.DESCRIPTION'
    ),
    routeName: 'captain_assistants_guidelines_index',
  },
]);

// ── Handlers — assistant ───────────────────────────────────────────────────
const handleSubmit = async updatedAssistant => {
  try {
    await store.dispatch('captainAssistants/update', {
      id: assistantId.value,
      ...updatedAssistant,
    });
    useAlert(t('CAPTAIN.ASSISTANTS.EDIT.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.ASSISTANTS.EDIT.ERROR_MESSAGE'));
  }
};

const handleDeleteAssistant = () =>
  deleteAssistantDialog.value.dialogRef.open();

const handleDeleteAssistantSuccess = () => {
  const remaining = assistants.value.filter(a => a.id !== assistantId.value);
  if (remaining.length > 0) {
    router.push({
      name: 'captain_assistants_settings_index',
      params: {
        accountId: route.params.accountId,
        assistantId: remaining[0].id,
      },
    });
  } else {
    router.push({
      name: 'captain_assistants_create_index',
      params: { accountId: route.params.accountId },
    });
  }
};

// ── Handlers — capabilities ────────────────────────────────────────────────
const handleCapabilityToggle = async item => {
  if (savingToggleIds.value.includes(item.id)) return;
  const config = { ...assistant.value.config, [item.id]: !item.enabled };
  toolStateOverrides.value = {
    ...toolStateOverrides.value,
    [item.id]: !item.enabled,
  };
  savingToggleIds.value = [...savingToggleIds.value, item.id];
  try {
    await store.dispatch('captainAssistants/update', {
      id: Number(assistantId.value),
      config,
    });
    toolStateOverrides.value = {
      ...toolStateOverrides.value,
      [item.id]: config[item.id],
    };
    useAlert(t('CAPTAIN.ASSISTANTS.EDIT.SUCCESS_MESSAGE'));
  } catch {
    toolStateOverrides.value = {
      ...toolStateOverrides.value,
      [item.id]: item.enabled,
    };
    useAlert(t('CAPTAIN.ASSISTANTS.EDIT.ERROR_MESSAGE'));
  } finally {
    savingToggleIds.value = savingToggleIds.value.filter(id => id !== item.id);
  }
};

const handleCaptainFeatureToggle = async item => {
  if (savingToggleIds.value.includes(item.id)) return;
  const enabled = !item.enabled;
  toolStateOverrides.value = {
    ...toolStateOverrides.value,
    [item.id]: enabled,
  };
  savingToggleIds.value = [...savingToggleIds.value, item.id];
  try {
    await captainConfigStore.updatePreferences({
      captain_features: { [item.id]: enabled },
    });
    toolStateOverrides.value = {
      ...toolStateOverrides.value,
      [item.id]: enabled,
    };
    useAlert(t('CAPTAIN_SETTINGS.API.SUCCESS'));
  } catch {
    toolStateOverrides.value = {
      ...toolStateOverrides.value,
      [item.id]: item.enabled,
    };
    useAlert(t('CAPTAIN_SETTINGS.API.ERROR'));
    captainConfigStore.fetch();
  } finally {
    savingToggleIds.value = savingToggleIds.value.filter(id => id !== item.id);
  }
};

const handleBuiltInToolToggle = async item => {
  if (savingToggleIds.value.includes(item.id)) return;
  const prevTool = builtInTools.value.find(bt => bt.id === item.id);
  if (!prevTool) return;
  const previousEnabled = prevTool.enabled;
  savingToggleIds.value = [...savingToggleIds.value, item.id];
  builtInTools.value = builtInTools.value.map(bt =>
    bt.id === item.id ? { ...bt, enabled: !previousEnabled } : bt
  );
  const disabledIds = builtInTools.value
    .filter(bt => !bt.enabled)
    .map(bt => bt.id);
  try {
    await CaptainAssistantAPI.updateDisabledBuiltInTools(
      assistantId.value,
      disabledIds
    );
    useAlert(t('CAPTAIN.BUILT_IN_TOOLS.TOGGLE_SUCCESS'));
  } catch {
    builtInTools.value = builtInTools.value.map(bt =>
      bt.id === item.id ? { ...bt, enabled: previousEnabled } : bt
    );
    useAlert(t('CAPTAIN.BUILT_IN_TOOLS.TOGGLE_ERROR'));
  } finally {
    savingToggleIds.value = savingToggleIds.value.filter(id => id !== item.id);
  }
};

// ── Handlers — custom tools ────────────────────────────────────────────────
const fetchCustomTools = (page = 1) =>
  store.dispatch('captainCustomTools/get', { page });

const fetchBuiltInTools = async () => {
  if (!assistantId.value) return;
  try {
    const { data } = await CaptainAssistantAPI.getBuiltInTools(
      assistantId.value
    );
    builtInTools.value = data;
  } catch {
    builtInTools.value = [];
  }
};

const openCreateToolDialog = () => {
  toolDialogType.value = 'create';
  selectedTool.value = null;
  nextTick(() => createToolDialogRef.value.dialogRef.open());
};

const handleEditTool = tool => {
  toolDialogType.value = 'edit';
  selectedTool.value = tool;
  nextTick(() => createToolDialogRef.value.dialogRef.open());
};

const handleDeleteTool = tool => {
  selectedTool.value = tool;
  nextTick(() => deleteToolDialogRef.value.dialogRef.open());
};

const handleToolDialogClose = () => {
  toolDialogType.value = '';
  selectedTool.value = null;
};

const onDeleteToolSuccess = () => {
  selectedTool.value = null;
  if (customTools.value.length === 1 && customToolsMeta.value.page > 1) {
    fetchCustomTools(customToolsMeta.value.page - 1);
  } else {
    fetchCustomTools(customToolsMeta.value.page);
  }
};

onMounted(() => {
  fetchCustomTools();
  fetchBuiltInTools();
  captainConfigStore.fetch();
});
</script>

<template>
  <PageLayout
    :is-fetching="isFetching"
    :show-pagination-footer="false"
    :show-know-more="false"
  >
    <template #body>
      <div class="flex flex-col gap-4 pb-8">
        <!-- ── Basic Settings ─────────────────────────────────── -->
        <div class="rounded-xl border border-n-weak bg-n-solid-1">
          <div
            class="flex items-center gap-3 px-5 py-4 border-b border-n-weak bg-n-solid-2"
          >
            <div
              class="flex items-center justify-center size-9 rounded-lg bg-n-amber-3 flex-shrink-0"
            >
              <span class="i-lucide-bot size-5 text-n-amber-11" />
            </div>
            <div>
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ t('CAPTAIN.ASSISTANTS.SETTINGS.BASIC_SETTINGS.TITLE') }}
              </h3>
              <p class="text-xs text-n-slate-10 mt-0.5">
                {{
                  t('CAPTAIN.ASSISTANTS.SETTINGS.BASIC_SETTINGS.DESCRIPTION')
                }}
              </p>
            </div>
          </div>
          <div class="p-5 w-full">
            <AssistantBasicSettingsForm
              :assistant="assistant"
              @submit="handleSubmit"
            />
          </div>
        </div>

        <!-- ── System Settings ────────────────────────────────── -->
        <div class="rounded-xl border border-n-weak bg-n-solid-1">
          <div
            class="flex items-center gap-3 px-5 py-4 border-b border-n-weak bg-n-solid-2"
          >
            <div
              class="flex items-center justify-center size-9 rounded-lg bg-n-blue-3 flex-shrink-0"
            >
              <span class="i-lucide-settings-2 size-5 text-n-blue-11" />
            </div>
            <div>
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ t('CAPTAIN.ASSISTANTS.SETTINGS.SYSTEM_SETTINGS.TITLE') }}
              </h3>
              <p class="text-xs text-n-slate-10 mt-0.5">
                {{
                  t('CAPTAIN.ASSISTANTS.SETTINGS.SYSTEM_SETTINGS.DESCRIPTION')
                }}
              </p>
            </div>
          </div>
          <div class="p-5 w-full">
            <AssistantSystemSettingsForm
              :assistant="assistant"
              @submit="handleSubmit"
            />
          </div>
        </div>

        <!-- ── Connected Inboxes ──────────────────────────────── -->
        <div class="rounded-xl border border-n-weak bg-n-solid-1">
          <div
            class="flex items-center justify-between gap-3 px-5 py-4 border-b border-n-weak bg-n-solid-2"
          >
            <div class="flex items-center gap-3 min-w-0">
              <div
                class="flex items-center justify-center size-9 rounded-lg bg-n-teal-3 flex-shrink-0"
              >
                <span class="i-lucide-inbox size-5 text-n-teal-11" />
              </div>
              <div class="min-w-0">
                <h3 class="text-sm font-semibold text-n-slate-12">
                  {{ t('CAPTAIN.INBOXES.HEADER') }}
                </h3>
              </div>
            </div>
            <Policy :permissions="['administrator']">
              <Button
                :label="t('CAPTAIN.INBOXES.ADD_NEW')"
                icon="i-lucide-plus"
                size="sm"
                color="black"
                class="flex-shrink-0"
                @click="handleInboxCreate"
              />
            </Policy>
          </div>
          <div class="p-4">
            <div v-if="captainInboxes.length" class="flex flex-col gap-2">
              <InboxCard
                v-for="inbox in captainInboxes"
                :id="inbox.id"
                :key="inbox.id"
                :inbox="inbox"
                @action="handleInboxAction"
              />
            </div>
            <div
              v-else
              class="flex flex-col items-center justify-center py-8 gap-3 text-center"
            >
              <span class="i-lucide-inbox size-8 text-n-slate-7" />
              <p class="text-sm text-n-slate-9">
                {{ t('CAPTAIN.INBOXES.EMPTY_STATE.DESCRIPTION') }}
              </p>
              <Policy :permissions="['administrator']">
                <Button
                  :label="t('CAPTAIN.INBOXES.ADD_NEW')"
                  icon="i-lucide-plus"
                  size="sm"
                  color="slate"
                  @click="handleInboxCreate"
                />
              </Policy>
            </div>
          </div>
        </div>

        <!-- ── Tools & Sources ────────────────────────────────── -->
        <div
          v-if="isCaptainV2Enabled"
          class="rounded-xl border border-n-weak bg-n-solid-1"
        >
          <div
            class="flex items-center justify-between gap-3 px-5 py-4 border-b border-n-weak bg-n-solid-2"
          >
            <div class="flex items-center gap-3 min-w-0">
              <div
                class="flex items-center justify-center size-9 rounded-lg bg-n-violet-3 flex-shrink-0"
              >
                <span class="i-lucide-blocks size-5 text-n-violet-11" />
              </div>
              <div class="min-w-0">
                <h3 class="text-sm font-semibold text-n-slate-12">
                  {{ t('CAPTAIN.CUSTOM_TOOLS.HEADER') }}
                </h3>
                <p class="text-xs text-n-slate-10 mt-0.5">
                  {{ t('CAPTAIN.CUSTOM_TOOLS.FORM_DESCRIPTION') }}
                </p>
              </div>
            </div>
            <Policy :permissions="['administrator']">
              <Button
                :label="t('CAPTAIN.CUSTOM_TOOLS.ADD_NEW')"
                icon="i-lucide-plus"
                size="sm"
                color="black"
                class="flex-shrink-0"
                @click="openCreateToolDialog"
              />
            </Policy>
          </div>
          <div class="p-4 flex flex-col gap-3">
            <ToolCategorySection
              :title="$t('CAPTAIN.ASSISTANTS.FORM.FEATURES.TITLE')"
              icon="i-lucide-sparkles"
              icon-color="text-n-amber-11"
              bg-color="bg-n-amber-3"
              :collapsed-by-default="false"
              :items="capabilities"
              :disabled-toggle-ids="savingToggleIds"
              @toggle="handleCapabilityToggle"
            />

            <ToolCategorySection
              v-if="captainFeatureCapabilities.length"
              :title="$t('CAPTAIN_SETTINGS.FEATURES.TITLE')"
              :description="$t('CAPTAIN_SETTINGS.FEATURES.DESCRIPTION')"
              icon="i-lucide-bot"
              icon-color="text-n-sky-11"
              bg-color="bg-n-sky-3"
              :items="captainFeatureCapabilities"
              :disabled-toggle-ids="savingToggleIds"
              @toggle="handleCaptainFeatureToggle"
            />

            <ToolCategorySection
              v-for="section in builtInCategorySections"
              :key="section.key"
              :title="section.title"
              :description="section.description"
              :icon="section.icon"
              :icon-color="section.iconColor"
              :bg-color="section.bgColor"
              :items="section.items"
              :disabled-toggle-ids="savingToggleIds"
              @toggle="handleBuiltInToolToggle"
            />

            <ToolCategorySection
              v-if="customToolItems.length"
              :title="$t('CAPTAIN.BUILT_IN_TOOLS.CUSTOM_HEADER')"
              :description="$t('CAPTAIN.BUILT_IN_TOOLS.CUSTOM_DESCRIPTION')"
              icon="i-lucide-wrench"
              icon-color="text-n-violet-11"
              bg-color="bg-n-violet-3"
              :items="customToolItems"
              hide-toggle
              @edit="handleEditTool"
            >
              <template #item-actions="{ item }">
                <Policy :permissions="['administrator']">
                  <button
                    class="flex-shrink-0 p-1 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
                    :title="$t('CAPTAIN.CUSTOM_TOOLS.OPTIONS.EDIT_TOOL')"
                    @click.stop="handleEditTool(item)"
                  >
                    <span class="i-lucide-pencil-line size-4" />
                  </button>
                  <button
                    class="flex-shrink-0 p-1 rounded text-n-slate-9 hover:text-n-ruby-11 hover:bg-n-alpha-2 transition-colors"
                    :title="$t('CAPTAIN.CUSTOM_TOOLS.OPTIONS.DELETE_TOOL')"
                    @click.stop="handleDeleteTool(item)"
                  >
                    <span class="i-lucide-trash size-4" />
                  </button>
                </Policy>
              </template>
            </ToolCategorySection>
          </div>
        </div>

        <!-- ── Controls (Guardrails & Guidelines) ─────────────── -->
        <div
          v-if="isCaptainV2Enabled"
          class="rounded-xl border border-n-weak bg-n-solid-1"
        >
          <div
            class="flex items-center gap-3 px-5 py-4 border-b border-n-weak bg-n-solid-2"
          >
            <div
              class="flex items-center justify-center size-9 rounded-lg bg-n-green-3 flex-shrink-0"
            >
              <span class="i-lucide-shield-check size-5 text-n-green-11" />
            </div>
            <div>
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ t('CAPTAIN.ASSISTANTS.SETTINGS.CONTROL_ITEMS.TITLE') }}
              </h3>
              <p class="text-xs text-n-slate-10 mt-0.5">
                {{ t('CAPTAIN.ASSISTANTS.SETTINGS.CONTROL_ITEMS.DESCRIPTION') }}
              </p>
            </div>
          </div>
          <div class="p-4 grid grid-cols-1 sm:grid-cols-2 gap-3">
            <AssistantControlItems
              v-for="item in controlItems"
              :key="item.name"
              :control-item="item"
            />
          </div>
        </div>

        <!-- ── Danger Zone ─────────────────────────────────────── -->
        <div class="rounded-xl border border-n-ruby-6 bg-n-ruby-2">
          <div
            class="flex items-center gap-3 px-5 py-4 border-b border-n-ruby-6"
          >
            <div
              class="flex items-center justify-center size-9 rounded-lg bg-n-ruby-3 flex-shrink-0"
            >
              <span class="i-lucide-trash-2 size-5 text-n-ruby-11" />
            </div>
            <div>
              <h3 class="text-sm font-semibold text-n-ruby-12">
                {{ t('CAPTAIN.ASSISTANTS.SETTINGS.DELETE.TITLE') }}
              </h3>
              <p class="text-xs text-n-ruby-11 mt-0.5">
                {{ t('CAPTAIN.ASSISTANTS.SETTINGS.DELETE.DESCRIPTION') }}
              </p>
            </div>
          </div>
          <div class="px-5 py-4 flex justify-end">
            <Button
              :label="
                t('CAPTAIN.ASSISTANTS.SETTINGS.DELETE.BUTTON_TEXT', {
                  assistantName: assistant?.name,
                })
              "
              color="ruby"
              class="!w-fit"
              @click="handleDeleteAssistant"
            />
          </div>
        </div>
      </div>
    </template>

    <DeleteDialog
      v-if="assistant"
      ref="deleteAssistantDialog"
      :entity="assistant"
      type="Assistants"
      translation-key="ASSISTANTS"
      @delete-success="handleDeleteAssistantSuccess"
    />
  </PageLayout>

  <!-- Inbox dialogs -->
  <ConnectInboxDialog
    v-if="inboxDialogType"
    ref="connectInboxDialog"
    :assistant-id="assistantId"
    :type="inboxDialogType"
    @close="handleInboxCreateClose"
  />
  <DeleteDialog
    v-if="selectedInbox"
    ref="disconnectInboxDialog"
    :entity="selectedInbox"
    :delete-payload="{ assistantId, inboxId: selectedInbox.id }"
    type="Inboxes"
  />

  <!-- Tool dialogs -->
  <CreateCustomToolDialog
    v-if="toolDialogType"
    ref="createToolDialogRef"
    :type="toolDialogType"
    :selected-tool="selectedTool"
    @close="handleToolDialogClose"
  />
  <DeleteDialog
    v-if="selectedTool"
    ref="deleteToolDialogRef"
    :entity="selectedTool"
    type="CustomTools"
    translation-key="CUSTOM_TOOLS"
    @delete-success="onDeleteToolSuccess"
  />
</template>
