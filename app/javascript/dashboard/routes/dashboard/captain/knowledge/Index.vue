<script setup>
import { computed, onMounted, ref, nextTick, h } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { debounce } from '@chatwoot/utils';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { picoSearch } from '@scmmishra/pico-search';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

import Banner from 'dashboard/components-next/banner/Banner.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import BulkSelectBar from 'dashboard/components-next/captain/assistant/BulkSelectBar.vue';
import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';
import BulkDeleteDialog from 'dashboard/components-next/captain/pageComponents/BulkDeleteDialog.vue';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import ResponseCard from 'dashboard/components-next/captain/assistant/ResponseCard.vue';
import DocumentCard from 'dashboard/components-next/captain/assistant/DocumentCard.vue';
import CreateResponseDialog from 'dashboard/components-next/captain/pageComponents/response/CreateResponseDialog.vue';
import CreateDocumentDialog from 'dashboard/components-next/captain/pageComponents/document/CreateDocumentDialog.vue';
import RelatedResponses from 'dashboard/components-next/captain/pageComponents/document/RelatedResponses.vue';
import ResponsePageEmptyState from 'dashboard/components-next/captain/pageComponents/emptyStates/ResponsePageEmptyState.vue';
import DocumentPageEmptyState from 'dashboard/components-next/captain/pageComponents/emptyStates/DocumentPageEmptyState.vue';
import FeatureSpotlightPopover from 'dashboard/components-next/feature-spotlight/FeatureSpotlightPopover.vue';
import FaqLimitBanner from 'dashboard/components-next/captain/pageComponents/response/LimitBanner.vue';
import DocLimitBanner from 'dashboard/components-next/captain/pageComponents/document/LimitBanner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SuggestedScenarios from 'dashboard/components-next/captain/assistant/SuggestedRules.vue';
import ScenariosCard from 'dashboard/components-next/captain/assistant/ScenariosCard.vue';
import AddNewScenariosDialog from 'dashboard/components-next/captain/assistant/AddNewScenariosDialog.vue';

const router = useRouter();
const route = useRoute();
const store = useStore();
const { isOnChatwootCloud } = useAccount();
const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();
const { formatMessage } = useMessageFormatter();

// ─── Tab state ────────────────────────────────────────────────────────────────

const tabs = computed(() => [
  { label: t('CAPTAIN.RESPONSES.HEADER') },
  { label: t('CAPTAIN.DOCUMENTS.HEADER') },
  { label: t('CAPTAIN.ASSISTANTS.SCENARIOS.TITLE') },
]);

const activeTabIndex = ref(0);
const isFaqTab = computed(() => activeTabIndex.value === 0);
const isDocTab = computed(() => activeTabIndex.value === 1);
const isScenariosTab = computed(() => activeTabIndex.value === 2);

// ─── Common ───────────────────────────────────────────────────────────────────

const selectedAssistantId = computed(() => Number(route.params.assistantId));

// ─── FAQ (Responses) state ────────────────────────────────────────────────────

const uiFlagsResponses = useMapGetter('captainResponses/getUIFlags');
const responseMeta = useMapGetter('captainResponses/getMeta');
const responses = useMapGetter('captainResponses/getRecords');
const isFetchingResponses = computed(() => uiFlagsResponses.value.fetchingList);
const pendingCount = useMapGetter('captainResponses/getPendingCount');

const selectedResponse = ref(null);
const responseDeleteDialog = ref(null);
const bulkDeleteDialog = ref(null);
const responseDialogType = ref('');
const searchQuery = ref('');
const createResponseDialog = ref(null);

const bulkSelectedIds = ref(new Set());
const hoveredCard = ref(null);

// Scenarios store (declared early — referenced in shared computed below)
const uiFlagsScenarios = useMapGetter('captainScenarios/getUIFlags');
const isFetchingScenarios = computed(() => uiFlagsScenarios.value.fetchingList);
const scenarios = useMapGetter('captainScenarios/getRecords');

const onTabChanged = tab => {
  const index = tabs.value.findIndex(item => item.label === tab.label);
  if (index !== -1) activeTabIndex.value = index;
  bulkSelectedIds.value = new Set();
};

const buildSelectedCountLabel = computed(() => {
  if (isScenariosTab.value) {
    const count = scenarios.value.length || 0;
    const isAllSelected = bulkSelectedIds.value.size === count && count > 0;
    return isAllSelected
      ? t('CAPTAIN.ASSISTANTS.SCENARIOS.BULK_ACTION.UNSELECT_ALL', { count })
      : t('CAPTAIN.ASSISTANTS.SCENARIOS.BULK_ACTION.SELECT_ALL', { count });
  }
  const count = responses.value?.length || 0;
  const isAllSelected = bulkSelectedIds.value.size === count && count > 0;
  return isAllSelected
    ? t('CAPTAIN.RESPONSES.UNSELECT_ALL', { count })
    : t('CAPTAIN.RESPONSES.SELECT_ALL', { count });
});

const selectedCountLabel = computed(() =>
  isScenariosTab.value
    ? t('CAPTAIN.ASSISTANTS.SCENARIOS.BULK_ACTION.SELECTED', {
        count: bulkSelectedIds.value.size,
      })
    : t('CAPTAIN.RESPONSES.SELECTED', { count: bulkSelectedIds.value.size })
);

const updateURLWithFilters = (page, search) => {
  const query = { page: page || 1 };
  if (search) query.search = search;
  router.replace({ query });
};

const fetchResponses = (page = 1) => {
  const filterParams = { page, status: 'approved' };
  if (selectedAssistantId.value)
    filterParams.assistantId = selectedAssistantId.value;
  if (searchQuery.value) filterParams.search = searchQuery.value;
  updateURLWithFilters(page, searchQuery.value);
  store.dispatch('captainResponses/get', filterParams);
};

const debouncedSearch = debounce(() => fetchResponses(1), 500);

const handleCreateFaq = () => {
  responseDialogType.value = 'create';
  nextTick(() => createResponseDialog.value.dialogRef.open());
};

const handleEditFaq = () => {
  responseDialogType.value = 'edit';
  nextTick(() => createResponseDialog.value.dialogRef.open());
};

const handleResponseAction = ({ action, id }) => {
  selectedResponse.value = responses.value.find(r => r.id === id);
  nextTick(() => {
    if (action === 'delete') responseDeleteDialog.value.dialogRef.open();
    if (action === 'edit') handleEditFaq();
  });
};

const handleResponseNavigate = ({ id, type }) => {
  if (type === 'Conversation') {
    router.push({
      name: 'inbox_conversation',
      params: { conversation_id: id },
    });
  }
};

const handleCreateResponseClose = () => {
  responseDialogType.value = '';
  selectedResponse.value = null;
};

const handleCardHover = (isHovered, id) => {
  hoveredCard.value = isHovered ? id : null;
};

const handleCardSelect = id => {
  const selected = new Set(bulkSelectedIds.value);
  selected[selected.has(id) ? 'delete' : 'add'](id);
  bulkSelectedIds.value = selected;
};

const fetchResponseAfterBulkAction = () => {
  const hasNoLeft = responses.value?.length === 0;
  const currentPage = responseMeta.value?.page;
  fetchResponses(hasNoLeft && currentPage > 1 ? currentPage - 1 : currentPage);
  bulkSelectedIds.value = new Set();
};

const onResponseDeleteSuccess = () => {
  if (responses.value?.length === 0 && responseMeta.value?.page > 1) {
    fetchResponses(responseMeta.value.page - 1);
  }
};

const navigateToPendingFAQs = () => {
  router.push({ name: 'captain_assistants_responses_pending' });
};

// ─── Documents state ──────────────────────────────────────────────────────────

const uiFlagsDocuments = useMapGetter('captainDocuments/getUIFlags');
const documentsMeta = useMapGetter('captainDocuments/getMeta');
const documents = useMapGetter('captainDocuments/getRecords');
const isFetchingDocuments = computed(() => uiFlagsDocuments.value.fetchingList);

const selectedDocument = ref(null);
const documentDeleteDialog = ref(null);
const showRelatedResponses = ref(false);
const showCreateDocumentDialog = ref(false);
const createDocumentDialog = ref(null);
const relationQuestionDialog = ref(null);

const fetchDocuments = (page = 1) => {
  const filterParams = { page };
  if (selectedAssistantId.value)
    filterParams.assistantId = selectedAssistantId.value;
  store.dispatch('captainDocuments/get', filterParams);
};

const handleCreateDocument = () => {
  showCreateDocumentDialog.value = true;
  nextTick(() => createDocumentDialog.value.dialogRef.open());
};

const handleDocumentAction = ({ action, id }) => {
  selectedDocument.value = documents.value.find(d => d.id === id);
  nextTick(() => {
    if (action === 'delete') documentDeleteDialog.value.dialogRef.open();
    if (action === 'viewRelatedQuestions') {
      showRelatedResponses.value = true;
      nextTick(() => relationQuestionDialog.value.dialogRef.open());
    }
  });
};

const handleDocumentDeleteSuccess = () => {
  if (documents.value?.length === 0 && documentsMeta.value?.page > 1) {
    fetchDocuments(documentsMeta.value.page - 1);
  }
};

const handleRelatedResponseClose = () => {
  showRelatedResponses.value = false;
};

const handleCreateDocumentClose = () => {
  showCreateDocumentDialog.value = false;
};

// ─── Scenarios state ──────────────────────────────────────────────────────────

const scenarioSearchQuery = ref('');

const LINK_INSTRUCTION_CLASS =
  '[&_a[href^="tool://"]]:text-n-iris-11 [&_a:not([href^="tool://"])]:text-n-slate-12 [&_a]:pointer-events-none [&_a]:cursor-default';

const renderInstruction = instruction => () =>
  h('span', {
    class: `text-sm text-n-slate-12 py-4 prose prose-sm min-w-0 break-words ${LINK_INSTRUCTION_CLASS}`,
    innerHTML: instruction,
  });

const scenariosExample = [
  {
    id: 1,
    title: 'Prospective Buyer',
    description:
      'Handle customers who are showing interest in purchasing a license',
    instruction:
      'If someone is interested in purchasing a license, ask them for following:\n\n1. How many licenses are they willing to purchase?\n2. Are they migrating from another platform?\n. Once these details are collected, do the following steps\n1. add a private note to with the information you collected using [Add Private Note](tool://add_private_note)\n2. Add label "sales" to the contact using [Add Label to Conversation](tool://add_label_to_conversation)\n3. Reply saying "one of us will reach out soon" and provide an estimated timeline for the response and [Handoff to Human](tool://handoff)',
    tools: ['add_private_note', 'add_label_to_conversation', 'handoff'],
  },
];

const filteredScenarios = computed(() => {
  const query = scenarioSearchQuery.value.trim();
  if (!query) return scenarios.value;
  return picoSearch(scenarios.value, query, [
    'title',
    'description',
    'instruction',
  ]);
});

const shouldShowSuggestedRules = computed(
  () => uiSettings.value?.show_scenarios_suggestions !== false
);

const closeSuggestedRules = () => {
  updateUISettings({ show_scenarios_suggestions: false });
};

const scenarioBulkSelectedIds = ref(new Set());
const hoveredScenarioCard = ref(null);

const handleScenarioSelect = id => {
  const selected = new Set(scenarioBulkSelectedIds.value);
  selected[selected.has(id) ? 'delete' : 'add'](id);
  scenarioBulkSelectedIds.value = selected;
};

const scenarioBuildSelectedCountLabel = computed(() => {
  const count = scenarios.value.length || 0;
  const isAllSelected =
    scenarioBulkSelectedIds.value.size === count && count > 0;
  return isAllSelected
    ? t('CAPTAIN.ASSISTANTS.SCENARIOS.BULK_ACTION.UNSELECT_ALL', { count })
    : t('CAPTAIN.ASSISTANTS.SCENARIOS.BULK_ACTION.SELECT_ALL', { count });
});

const scenarioSelectedCountLabel = computed(() =>
  t('CAPTAIN.ASSISTANTS.SCENARIOS.BULK_ACTION.SELECTED', {
    count: scenarioBulkSelectedIds.value.size,
  })
);

const handleScenarioHover = (isHovered, id) => {
  hoveredScenarioCard.value = isHovered ? id : null;
};

const getToolsFromInstruction = instruction => [
  ...new Set(
    [...(instruction?.matchAll(/\(tool:\/\/([^)]+)\)/g) ?? [])].map(m => m[1])
  ),
];

const updateScenario = async scenario => {
  try {
    await store.dispatch('captainScenarios/update', {
      id: scenario.id,
      assistantId: selectedAssistantId.value,
      ...scenario,
      tools: getToolsFromInstruction(scenario.instruction),
    });
    useAlert(t('CAPTAIN.ASSISTANTS.SCENARIOS.API.UPDATE.SUCCESS'));
  } catch (error) {
    useAlert(
      error?.response?.message ||
        t('CAPTAIN.ASSISTANTS.SCENARIOS.API.UPDATE.ERROR')
    );
  }
};

const deleteScenario = async id => {
  try {
    await store.dispatch('captainScenarios/delete', {
      id,
      assistantId: selectedAssistantId.value,
    });
    useAlert(t('CAPTAIN.ASSISTANTS.SCENARIOS.API.DELETE.SUCCESS'));
  } catch (error) {
    useAlert(
      error?.response?.message ||
        t('CAPTAIN.ASSISTANTS.SCENARIOS.API.DELETE.ERROR')
    );
  }
};

const bulkDeleteScenarios = async ids => {
  const idsArray = ids || Array.from(scenarioBulkSelectedIds.value);
  await Promise.all(
    idsArray.map(id =>
      store.dispatch('captainScenarios/delete', {
        id,
        assistantId: selectedAssistantId.value,
      })
    )
  );
  scenarioBulkSelectedIds.value = new Set();
  useAlert(t('CAPTAIN.ASSISTANTS.SCENARIOS.API.DELETE.SUCCESS'));
};

const addScenario = async scenario => {
  try {
    await store.dispatch('captainScenarios/create', {
      assistantId: selectedAssistantId.value,
      ...scenario,
      tools: getToolsFromInstruction(scenario.instruction),
    });
    useAlert(t('CAPTAIN.ASSISTANTS.SCENARIOS.API.ADD.SUCCESS'));
  } catch (error) {
    useAlert(
      error?.response?.message ||
        t('CAPTAIN.ASSISTANTS.SCENARIOS.API.ADD.ERROR')
    );
  }
};

const addAllExampleScenarios = async () => {
  try {
    scenariosExample.forEach(async scenario => {
      await store.dispatch('captainScenarios/create', {
        assistantId: selectedAssistantId.value,
        ...scenario,
      });
    });
    useAlert(t('CAPTAIN.ASSISTANTS.SCENARIOS.API.ADD.SUCCESS'));
  } catch (error) {
    useAlert(
      error?.response?.message ||
        t('CAPTAIN.ASSISTANTS.SCENARIOS.API.ADD.ERROR')
    );
  }
};

// ─── PageLayout computed props ────────────────────────────────────────────────

const headerTitle = computed(() => t('CAPTAIN.KNOWLEDGE.HEADER'));

const buttonLabel = computed(() => {
  if (isFaqTab.value) return t('CAPTAIN.RESPONSES.ADD_NEW');
  if (isDocTab.value) return t('CAPTAIN.DOCUMENTS.ADD_NEW');
  return '';
});

const totalCount = computed(() =>
  isFaqTab.value
    ? responseMeta.value.totalCount
    : documentsMeta.value.totalCount
);

const currentPage = computed(() =>
  isFaqTab.value ? responseMeta.value.page : documentsMeta.value.page
);

const isFetching = computed(() => {
  if (isFaqTab.value) return isFetchingResponses.value;
  if (isDocTab.value) return isFetchingDocuments.value;
  return isFetchingScenarios.value;
});

const isEmpty = computed(() => {
  if (isFaqTab.value) return !responses.value.length;
  if (isDocTab.value) return !documents.value.length;
  return false;
});

const showPaginationFooter = computed(() => {
  if (isFaqTab.value)
    return !isFetchingResponses.value && !!responses.value.length;
  if (isDocTab.value)
    return !isFetchingDocuments.value && !!documents.value.length;
  return false;
});

const handleCreate = () => {
  if (isFaqTab.value) handleCreateFaq();
  else if (isDocTab.value) handleCreateDocument();
};

const onPageChange = page => {
  if (isFaqTab.value) {
    const hadSelection = bulkSelectedIds.value.size > 0;
    fetchResponses(page);
    if (hadSelection) bulkSelectedIds.value = new Set();
  } else {
    fetchDocuments(page);
  }
};

// ─── Init ─────────────────────────────────────────────────────────────────────

onMounted(() => {
  if (route.query.search) searchQuery.value = route.query.search;
  const pageFromURL = parseInt(route.query.page, 10) || 1;
  fetchResponses(pageFromURL);
  fetchDocuments();
  store.dispatch(
    'captainResponses/fetchPendingCount',
    selectedAssistantId.value
  );
  store.dispatch('captainScenarios/get', {
    assistantId: selectedAssistantId.value,
  });
  store.dispatch('captainTools/getTools');
});
</script>

<template>
  <PageLayout
    :header-title="headerTitle"
    :button-label="buttonLabel"
    :button-policy="['administrator']"
    :total-count="totalCount"
    :current-page="currentPage"
    :is-fetching="isFetching"
    :is-empty="isEmpty"
    :show-pagination-footer="showPaginationFooter"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
    @update:current-page="onPageChange"
    @click="handleCreate"
  >
    <template #knowMore>
      <FeatureSpotlightPopover
        v-if="isFaqTab"
        :button-label="$t('CAPTAIN.HEADER_KNOW_MORE')"
        :title="$t('CAPTAIN.RESPONSES.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
        :note="$t('CAPTAIN.RESPONSES.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
        :hide-actions="!isOnChatwootCloud"
        fallback-thumbnail="/assets/images/dashboard/captain/faqs-popover-light.svg"
        fallback-thumbnail-dark="/assets/images/dashboard/captain/faqs-popover-dark.svg"
        learn-more-url="https://chwt.app/captain-faq"
      />
      <FeatureSpotlightPopover
        v-else-if="isDocTab"
        :button-label="$t('CAPTAIN.HEADER_KNOW_MORE')"
        :title="$t('CAPTAIN.DOCUMENTS.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
        :note="$t('CAPTAIN.DOCUMENTS.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
        :hide-actions="!isOnChatwootCloud"
        fallback-thumbnail="/assets/images/dashboard/captain/document-popover-light.svg"
        fallback-thumbnail-dark="/assets/images/dashboard/captain/document-popover-dark.svg"
        learn-more-url="https://chwt.app/captain-document"
      />
    </template>

    <template #search>
      <div
        v-if="isFaqTab && bulkSelectedIds.size === 0"
        class="flex gap-3 justify-between w-full items-center"
      >
        <Input
          v-model="searchQuery"
          :placeholder="$t('CAPTAIN.RESPONSES.SEARCH_PLACEHOLDER')"
          class="w-64"
          size="sm"
          type="search"
          autofocus
          @input="debouncedSearch"
        />
      </div>
      <div
        v-else-if="
          isScenariosTab &&
          scenarios.length &&
          scenarioBulkSelectedIds.size === 0
        "
        class="flex gap-3 justify-between w-full items-center"
      >
        <Input
          v-model="scenarioSearchQuery"
          :placeholder="
            t('CAPTAIN.ASSISTANTS.SCENARIOS.LIST.SEARCH_PLACEHOLDER')
          "
          class="w-64"
          size="sm"
          type="search"
        />
      </div>
    </template>

    <template #subHeader>
      <div class="flex items-center gap-3 pb-3">
        <TabBar
          :tabs="tabs"
          :initial-active-tab="activeTabIndex"
          @tab-changed="onTabChanged"
        />
      </div>
      <BulkSelectBar
        v-if="isFaqTab"
        v-model="bulkSelectedIds"
        :all-items="responses"
        :select-all-label="buildSelectedCountLabel"
        :selected-count-label="selectedCountLabel"
        :delete-label="$t('CAPTAIN.RESPONSES.BULK_DELETE_BUTTON')"
        class="w-fit"
        :class="{ 'mb-2': bulkSelectedIds.size > 0 }"
        @bulk-delete="bulkDeleteDialog.dialogRef.open()"
      />
    </template>

    <template #emptyState>
      <ResponsePageEmptyState v-if="isFaqTab" @click="handleCreateFaq" />
      <DocumentPageEmptyState
        v-else-if="isDocTab"
        @click="handleCreateDocument"
      />
    </template>

    <template #paywall>
      <CaptainPaywall />
    </template>

    <template #body>
      <!-- FAQ tab -->
      <template v-if="isFaqTab">
        <FaqLimitBanner class="mb-5" />
        <Banner
          v-if="pendingCount > 0"
          color="blue"
          class="mb-4 -mt-3"
          :action-label="$t('CAPTAIN.RESPONSES.PENDING_BANNER.ACTION')"
          @action="navigateToPendingFAQs"
        >
          {{ $t('CAPTAIN.RESPONSES.PENDING_BANNER.TITLE') }}
        </Banner>
        <div class="flex flex-col gap-4">
          <ResponseCard
            v-for="response in responses"
            :id="response.id"
            :key="response.id"
            :question="response.question"
            :answer="response.answer"
            :assistant="response.assistant"
            :documentable="response.documentable"
            :status="response.status"
            :created-at="response.created_at"
            :updated-at="response.updated_at"
            :is-selected="bulkSelectedIds.has(response.id)"
            :selectable="
              hoveredCard === response.id || bulkSelectedIds.size > 0
            "
            :show-menu="!bulkSelectedIds.has(response.id)"
            :show-actions="false"
            @action="handleResponseAction"
            @navigate="handleResponseNavigate"
            @select="handleCardSelect"
            @hover="isHovered => handleCardHover(isHovered, response.id)"
          />
        </div>
      </template>

      <!-- Documents tab -->
      <template v-else-if="isDocTab">
        <DocLimitBanner class="mb-5" />
        <div class="flex flex-col gap-4">
          <DocumentCard
            v-for="doc in documents"
            :id="doc.id"
            :key="doc.id"
            :name="doc.name || doc.external_link"
            :external-link="doc.external_link"
            :assistant="doc.assistant"
            :created-at="doc.created_at"
            @action="handleDocumentAction"
          />
        </div>
      </template>

      <!-- Scenarios tab -->
      <template v-else-if="isScenariosTab">
        <div v-if="shouldShowSuggestedRules" class="flex mb-7 flex-col gap-4">
          <SuggestedScenarios
            :title="$t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.SUGGESTED.TITLE')"
            :items="scenariosExample"
            @close="closeSuggestedRules"
            @add="addAllExampleScenarios"
          >
            <template #default="{ item }">
              <div class="flex items-center gap-3 justify-between">
                <span class="text-sm text-n-slate-12">{{ item.title }}</span>
                <Button
                  :label="
                    $t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.SUGGESTED.ADD_SINGLE')
                  "
                  ghost
                  xs
                  slate
                  class="!text-sm !text-n-slate-11 flex-shrink-0"
                  @click="addScenario(item)"
                />
              </div>
              <div class="flex flex-col">
                <span class="text-sm text-n-slate-11 mt-2">{{
                  item.description
                }}</span>
                <component
                  :is="
                    renderInstruction(formatMessage(item.instruction, false))
                  "
                />
                <span class="text-sm text-n-slate-11 font-medium mb-1">
                  {{
                    t('CAPTAIN.ASSISTANTS.SCENARIOS.ADD.SUGGESTED.TOOLS_USED')
                  }}
                  {{ item.tools?.map(tool => `@${tool}`).join(', ') }}
                </span>
              </div>
            </template>
          </SuggestedScenarios>
        </div>
        <div class="flex flex-col gap-4">
          <div class="flex justify-between items-center">
            <BulkSelectBar
              v-model="scenarioBulkSelectedIds"
              :all-items="scenarios"
              :select-all-label="scenarioBuildSelectedCountLabel"
              :selected-count-label="scenarioSelectedCountLabel"
              :delete-label="
                $t(
                  'CAPTAIN.ASSISTANTS.SCENARIOS.BULK_ACTION.BULK_DELETE_BUTTON'
                )
              "
              @bulk-delete="bulkDeleteScenarios"
            >
              <template #default-actions>
                <AddNewScenariosDialog @add="addScenario" />
              </template>
            </BulkSelectBar>
          </div>
          <div v-if="scenarios.length === 0" class="mt-1 mb-2">
            <span class="text-n-slate-11 text-sm">
              {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.EMPTY_MESSAGE') }}
            </span>
          </div>
          <div v-else-if="filteredScenarios.length === 0" class="mt-1 mb-2">
            <span class="text-n-slate-11 text-sm">
              {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.SEARCH_EMPTY_MESSAGE') }}
            </span>
          </div>
          <div v-else class="flex flex-col gap-2">
            <ScenariosCard
              v-for="scenario in filteredScenarios"
              :id="scenario.id"
              :key="scenario.id"
              :title="scenario.title"
              :description="scenario.description"
              :instruction="scenario.instruction"
              :tools="scenario.tools"
              :is-selected="scenarioBulkSelectedIds.has(scenario.id)"
              :selectable="
                hoveredScenarioCard === scenario.id ||
                scenarioBulkSelectedIds.size > 0
              "
              @select="handleScenarioSelect"
              @delete="deleteScenario(scenario.id)"
              @update="updateScenario"
              @hover="isHovered => handleScenarioHover(isHovered, scenario.id)"
            />
          </div>
        </div>
      </template>
    </template>

    <!-- FAQ dialogs -->
    <DeleteDialog
      v-if="selectedResponse"
      ref="responseDeleteDialog"
      :entity="selectedResponse"
      type="Responses"
      @delete-success="onResponseDeleteSuccess"
    />
    <BulkDeleteDialog
      v-if="bulkSelectedIds"
      ref="bulkDeleteDialog"
      :bulk-ids="bulkSelectedIds"
      type="Responses"
      @delete-success="fetchResponseAfterBulkAction"
    />
    <CreateResponseDialog
      v-if="responseDialogType"
      ref="createResponseDialog"
      :type="responseDialogType"
      :selected-response="selectedResponse"
      @close="handleCreateResponseClose"
    />

    <!-- Document dialogs -->
    <RelatedResponses
      v-if="showRelatedResponses"
      ref="relationQuestionDialog"
      :captain-document="selectedDocument"
      @close="handleRelatedResponseClose"
    />
    <CreateDocumentDialog
      v-if="showCreateDocumentDialog"
      ref="createDocumentDialog"
      :assistant-id="selectedAssistantId"
      @close="handleCreateDocumentClose"
    />
    <DeleteDialog
      v-if="selectedDocument"
      ref="documentDeleteDialog"
      :entity="selectedDocument"
      type="Documents"
      @delete-success="handleDocumentDeleteSuccess"
    />
  </PageLayout>
</template>
