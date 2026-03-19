<script setup>
import { computed, onMounted, ref, nextTick } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import CaptainAssistantAPI from 'dashboard/api/captain/assistant';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import CustomToolsPageEmptyState from 'dashboard/components-next/captain/pageComponents/emptyStates/CustomToolsPageEmptyState.vue';
import CreateCustomToolDialog from 'dashboard/components-next/captain/pageComponents/customTool/CreateCustomToolDialog.vue';
import ToolCategorySection from 'dashboard/components-next/captain/pageComponents/customTool/ToolCategorySection.vue';
import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';
import Policy from 'dashboard/components/policy.vue';

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

const store = useStore();
const route = useRoute();
const { t, te } = useI18n();

const uiFlags = useMapGetter('captainCustomTools/getUIFlags');
const customTools = useMapGetter('captainCustomTools/getRecords');
const isFetching = computed(() => uiFlags.value.fetchingList);
const customToolsMeta = useMapGetter('captainCustomTools/getMeta');

const createDialogRef = ref(null);
const deleteDialogRef = ref(null);
const selectedTool = ref(null);
const dialogType = ref('');

const builtInTools = ref([]);
const isFetchingBuiltIn = ref(false);

const assistantId = computed(() => route.params.assistantId);

const localizeBuiltInTool = tool => {
  const titleKey = `CAPTAIN.BUILT_IN_TOOLS.TOOLS.${tool.id}.TITLE`;
  const descKey = `CAPTAIN.BUILT_IN_TOOLS.TOOLS.${tool.id}.DESCRIPTION`;
  return {
    ...tool,
    title: te(titleKey) ? t(titleKey) : tool.title,
    description: te(descKey) ? t(descKey) : tool.description,
  };
};

const builtInToolRows = computed(() =>
  builtInTools.value.map(tool => ({
    ...localizeBuiltInTool(tool),
    icon: ICON_MAP[tool.icon] || 'i-lucide-wrench',
    category: tool.category || 'core',
  }))
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

const isEmpty = computed(
  () => !customTools.value.length && !builtInTools.value.length
);

const customToolItems = computed(() =>
  customTools.value.map(tool => ({
    ...tool,
    icon: 'i-lucide-wrench',
    enabled: true,
  }))
);

const fetchCustomTools = (page = 1) => {
  store.dispatch('captainCustomTools/get', { page });
};

const fetchBuiltInTools = async () => {
  if (!assistantId.value) return;
  isFetchingBuiltIn.value = true;
  try {
    const { data } = await CaptainAssistantAPI.getBuiltInTools(
      assistantId.value
    );
    builtInTools.value = data;
  } catch {
    builtInTools.value = [];
  } finally {
    isFetchingBuiltIn.value = false;
  }
};

const handleBuiltInToolToggle = async item => {
  const id = item.id;
  const prevTool = builtInTools.value.find(bt => bt.id === id);
  if (!prevTool) return;

  const previousEnabled = prevTool.enabled;
  const enabled = !previousEnabled;
  builtInTools.value = builtInTools.value.map(bt =>
    bt.id === id ? { ...bt, enabled } : bt
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
      bt.id === id ? { ...bt, enabled: previousEnabled } : bt
    );
    useAlert(t('CAPTAIN.BUILT_IN_TOOLS.TOGGLE_ERROR'));
  }
};

const onPageChange = page => fetchCustomTools(page);

const openCreateDialog = () => {
  dialogType.value = 'create';
  selectedTool.value = null;
  nextTick(() => createDialogRef.value.dialogRef.open());
};

const handleEdit = tool => {
  dialogType.value = 'edit';
  selectedTool.value = tool;
  nextTick(() => createDialogRef.value.dialogRef.open());
};

const handleDelete = tool => {
  selectedTool.value = tool;
  nextTick(() => deleteDialogRef.value.dialogRef.open());
};

const handleDialogClose = () => {
  dialogType.value = '';
  selectedTool.value = null;
};

const onDeleteSuccess = () => {
  selectedTool.value = null;
  // Check if page will be empty after deletion
  if (customTools.value.length === 1 && customToolsMeta.value.page > 1) {
    // Go to previous page if current page will be empty
    onPageChange(customToolsMeta.value.page - 1);
  } else {
    // Refresh current page
    fetchCustomTools(customToolsMeta.value.page);
  }
};

onMounted(() => {
  fetchCustomTools();
  fetchBuiltInTools();
});
</script>

<template>
  <PageLayout
    :header-title="$t('CAPTAIN.CUSTOM_TOOLS.HEADER')"
    :button-label="$t('CAPTAIN.CUSTOM_TOOLS.ADD_NEW')"
    :button-policy="['administrator']"
    :total-count="customToolsMeta.totalCount"
    :current-page="customToolsMeta.page"
    :show-pagination-footer="!isFetching && !!customTools.length"
    :is-fetching="isFetching && isFetchingBuiltIn"
    :is-empty="isEmpty"
    :feature-flag="FEATURE_FLAGS.CAPTAIN_V2"
    :show-know-more="false"
    @update:current-page="onPageChange"
    @click="openCreateDialog"
  >
    <template #paywall>
      <CaptainPaywall />
    </template>

    <template #emptyState>
      <CustomToolsPageEmptyState @click="openCreateDialog" />
    </template>

    <template #body>
      <div class="flex flex-col gap-4 max-w-2xl">
        <ToolCategorySection
          v-for="section in builtInCategorySections"
          :key="section.key"
          :title="section.title"
          :description="section.description"
          :icon="section.icon"
          :icon-color="section.iconColor"
          :bg-color="section.bgColor"
          :items="section.items"
          @toggle="handleBuiltInToolToggle"
        />

        <ToolCategorySection
          v-if="customTools.length"
          :title="$t('CAPTAIN.BUILT_IN_TOOLS.CUSTOM_HEADER')"
          :description="$t('CAPTAIN.BUILT_IN_TOOLS.CUSTOM_DESCRIPTION')"
          icon="i-lucide-wrench"
          icon-color="text-n-violet-11"
          bg-color="bg-n-violet-3"
          :items="customToolItems"
          hide-toggle
          @edit="handleEdit"
        >
          <template #item-actions="{ item }">
            <Policy :permissions="['administrator']">
              <button
                class="flex-shrink-0 p-1 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
                :title="$t('CAPTAIN.CUSTOM_TOOLS.OPTIONS.EDIT_TOOL')"
                @click.stop="handleEdit(item)"
              >
                <span class="i-lucide-pencil-line size-4" />
              </button>
              <button
                class="flex-shrink-0 p-1 rounded text-n-slate-9 hover:text-n-ruby-11 hover:bg-n-alpha-2 transition-colors"
                :title="$t('CAPTAIN.CUSTOM_TOOLS.OPTIONS.DELETE_TOOL')"
                @click.stop="handleDelete(item)"
              >
                <span class="i-lucide-trash size-4" />
              </button>
            </Policy>
          </template>
        </ToolCategorySection>
      </div>
    </template>
  </PageLayout>

  <CreateCustomToolDialog
    v-if="dialogType"
    ref="createDialogRef"
    :type="dialogType"
    :selected-tool="selectedTool"
    @close="handleDialogClose"
  />

  <DeleteDialog
    v-if="selectedTool"
    ref="deleteDialogRef"
    :entity="selectedTool"
    type="CustomTools"
    translation-key="CUSTOM_TOOLS"
    @delete-success="onDeleteSuccess"
  />
</template>
