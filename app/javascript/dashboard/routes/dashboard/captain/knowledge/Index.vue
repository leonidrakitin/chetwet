<script setup>
import { computed, onMounted, ref, nextTick } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { debounce } from '@chatwoot/utils';
import { useAccount } from 'dashboard/composables/useAccount';

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

const router = useRouter();
const route = useRoute();
const store = useStore();
const { isOnChatwootCloud } = useAccount();
const { t } = useI18n();

// ─── Tab state ────────────────────────────────────────────────────────────────

const tabs = computed(() => [
  { label: t('CAPTAIN.RESPONSES.HEADER') },
  { label: t('CAPTAIN.DOCUMENTS.HEADER') },
]);

const activeTabIndex = ref(0);
const isFaqTab = computed(() => activeTabIndex.value === 0);

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

const onTabChanged = tab => {
  const index = tabs.value.findIndex(item => item.label === tab.label);
  if (index !== -1) activeTabIndex.value = index;
  bulkSelectedIds.value = new Set();
};

const buildSelectedCountLabel = computed(() => {
  const count = responses.value?.length || 0;
  const isAllSelected = bulkSelectedIds.value.size === count && count > 0;
  return isAllSelected
    ? t('CAPTAIN.RESPONSES.UNSELECT_ALL', { count })
    : t('CAPTAIN.RESPONSES.SELECT_ALL', { count });
});

const selectedCountLabel = computed(() =>
  t('CAPTAIN.RESPONSES.SELECTED', { count: bulkSelectedIds.value.size })
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

// ─── PageLayout computed props ────────────────────────────────────────────────

const headerTitle = computed(() => t('CAPTAIN.KNOWLEDGE.HEADER'));

const buttonLabel = computed(() =>
  isFaqTab.value
    ? t('CAPTAIN.RESPONSES.ADD_NEW')
    : t('CAPTAIN.DOCUMENTS.ADD_NEW')
);

const totalCount = computed(() =>
  isFaqTab.value
    ? responseMeta.value.totalCount
    : documentsMeta.value.totalCount
);

const currentPage = computed(() =>
  isFaqTab.value ? responseMeta.value.page : documentsMeta.value.page
);

const isFetching = computed(() =>
  isFaqTab.value ? isFetchingResponses.value : isFetchingDocuments.value
);

const isEmpty = computed(() =>
  isFaqTab.value ? !responses.value.length : !documents.value.length
);

const showPaginationFooter = computed(() =>
  isFaqTab.value
    ? !isFetchingResponses.value && !!responses.value.length
    : !isFetchingDocuments.value && !!documents.value.length
);

const handleCreate = () => {
  if (isFaqTab.value) handleCreateFaq();
  else handleCreateDocument();
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
        v-else
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
      <DocumentPageEmptyState v-else @click="handleCreateDocument" />
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
      <template v-else>
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
