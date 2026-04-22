<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CampaignCard from './components/CampaignCard.vue';
import StatisticsTab from './components/StatisticsTab.vue';
import NotificationTemplatePreview from '../notificationTemplates/components/NotificationTemplatePreview.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const uiFlags = computed(() => store.getters['campaigns/getUIFlags']);
const allCampaigns = computed(() => store.getters['campaigns/getCampaigns']);
const inboxes = computed(() => store.getters['inboxes/getInboxes']);
const isStatisticsTab = computed(() => route.name === 'campaigns_statistics');

const searchQuery = ref('');
const inboxFilter = ref('');

const filteredCampaigns = computed(() => {
  let campaigns = Array.isArray(allCampaigns.value) ? allCampaigns.value : [];

  if (inboxFilter.value) {
    campaigns = campaigns.filter(
      c => String(c.inbox_id) === String(inboxFilter.value)
    );
  }

  const q = searchQuery.value.trim().toLowerCase();
  if (q) {
    campaigns = campaigns.filter(
      c =>
        (c.name ?? c.title ?? '').toLowerCase().includes(q) ||
        (c.messageText ?? c.message ?? '').toLowerCase().includes(q)
    );
  }
  return campaigns;
});

const deleteDialogRef = ref(null);
const previewDialogRef = ref(null);
const deletingCampaign = ref(null);
const previewingCampaign = ref(null);

const sendDialogRef = ref(null);
const sendingCampaign = ref(null);
const isSending = ref(false);

const closeAllDialogs = () => {
  deleteDialogRef.value?.close();
  previewDialogRef.value?.close();
  sendDialogRef.value?.close();
};

const openNewCampaign = () => {
  router.push({
    name: 'campaigns_new',
    params: { accountId: route.params.accountId },
  });
};

const handleEdit = campaign => {
  router.push({
    name: 'campaigns_edit',
    params: { accountId: route.params.accountId, campaignId: campaign.id },
  });
};

const handleDeleteRequest = campaign => {
  closeAllDialogs();
  deletingCampaign.value = campaign;
  deleteDialogRef.value?.open();
};

const confirmDelete = async () => {
  if (!deletingCampaign.value) return;
  try {
    await store.dispatch('campaigns/delete', deletingCampaign.value.id);
    useAlert(t('CAMPAIGNS.DELETE.SUCCESS'));
  } catch {
    useAlert(t('CAMPAIGNS.DELETE.ERROR'));
  } finally {
    deletingCampaign.value = null;
    deleteDialogRef.value?.close();
  }
};

const handlePreview = campaign => {
  closeAllDialogs();
  previewingCampaign.value = campaign;
  previewDialogRef.value?.open();
};

const handleSendNowRequest = campaign => {
  closeAllDialogs();
  sendingCampaign.value = campaign;
  sendDialogRef.value?.open();
};

const confirmSendNow = async () => {
  if (!sendingCampaign.value) return;
  isSending.value = true;
  try {
    await store.dispatch('campaigns/sendNow', sendingCampaign.value.id);
    useAlert(t('CAMPAIGNS.SEND_SUCCESS'));
    store.dispatch('campaigns/get');
  } catch {
    useAlert(t('CAMPAIGNS.SEND_ERROR'));
  } finally {
    isSending.value = false;
    sendingCampaign.value = null;
    sendDialogRef.value?.close();
  }
};

watch(
  () => route.name,
  routeName => {
    if (routeName === 'campaigns_statistics') {
      store.dispatch('campaigns/fetchStatistics');
    }
  }
);

onMounted(() => {
  store.dispatch('campaigns/get');
  if (route.name === 'campaigns_statistics') {
    store.dispatch('campaigns/fetchStatistics');
  }
  if (!inboxes.value.length) {
    store.dispatch('inboxes/get');
  }
});
</script>

<template>
  <div
    class="flex flex-col h-full w-full min-w-0 overflow-hidden bg-n-surface-1"
  >
    <!-- Header -->
    <div
      class="sticky top-0 z-10 px-4 md:px-6 bg-n-surface-1 border-b border-n-weak flex-shrink-0"
    >
      <div
        class="flex items-start sm:items-center justify-between w-full py-4 md:py-5 gap-4"
      >
        <div class="flex items-center gap-2 min-w-0">
          <h1 class="text-lg font-semibold text-n-slate-12 truncate">
            {{ t('CAMPAIGNS.HEADER') }}
          </h1>
          <span
            v-if="!isStatisticsTab"
            class="text-sm font-normal text-n-slate-9"
          >
            {{ filteredCampaigns.length }}
          </span>
        </div>

        <!-- Controls row -->
        <div
          v-if="!isStatisticsTab"
          class="flex items-center flex-col sm:flex-row flex-shrink-0 gap-3 w-full sm:w-auto"
        >
          <div class="flex items-center gap-2 w-full sm:w-auto">
            <Input
              :model-value="searchQuery"
              type="search"
              :placeholder="t('CAMPAIGNS.SEARCH.PLACEHOLDER')"
              :custom-input-class="[
                'h-8 [&:not(.focus)]:!border-transparent bg-n-alpha-2 dark:bg-n-solid-1 ltr:!pl-8 !py-1 rtl:!pr-8',
              ]"
              class="w-full sm:w-48"
              @input="searchQuery = $event.target.value"
            >
              <template #prefix>
                <Icon
                  icon="i-lucide-search"
                  class="absolute -translate-y-1/2 text-n-slate-11 size-4 top-1/2 ltr:left-2 rtl:right-2"
                />
              </template>
            </Input>

            <select
              v-model="inboxFilter"
              class="h-8 w-full sm:w-40 rounded-lg border border-n-weak bg-n-alpha-1 pl-3 pr-8 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            >
              <option value="">
                {{ t('NOTIFICATION_TEMPLATES.FORM.INBOX.PLACEHOLDER') }}
              </option>
              <option
                v-for="inbox in inboxes"
                :key="inbox.id"
                :value="inbox.id"
              >
                {{ inbox.name }}
              </option>
            </select>
          </div>

          <div class="flex items-center flex-shrink-0 gap-2 sm:gap-4">
            <Button
              :label="t('CAMPAIGNS.NEW_CAMPAIGN')"
              icon="i-lucide-plus"
              size="sm"
              @click="openNewCampaign"
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Content -->
    <div class="flex-1 min-h-0 overflow-y-auto px-4 py-3 md:px-6 md:py-4">
      <!-- Loading (list tab only; statistics tab handles its own loading and must not be unmounted by campaigns/get) -->
      <div
        v-if="uiFlags.isFetching && !isStatisticsTab"
        class="flex justify-center items-center py-10 text-n-slate-11"
      >
        <Spinner />
      </div>

      <!-- Statistics tab -->
      <StatisticsTab v-else-if="isStatisticsTab" />

      <!-- Empty state -->
      <div
        v-else-if="filteredCampaigns.length === 0"
        class="flex flex-col items-center justify-center h-full gap-4 py-12"
      >
        <div
          class="flex items-center justify-center size-16 rounded-2xl bg-n-alpha-1"
        >
          <span class="i-lucide-megaphone size-8 text-n-slate-9" />
        </div>
        <div class="flex flex-col items-center gap-1 text-center">
          <p class="text-base font-medium text-n-slate-12">
            {{
              searchQuery
                ? t('CAMPAIGNS.EMPTY_SEARCH_TITLE')
                : t('CAMPAIGNS.EMPTY_TITLE')
            }}
          </p>
          <p class="text-sm text-n-slate-10 max-w-sm">
            {{
              searchQuery
                ? t('CAMPAIGNS.EMPTY_SEARCH_DESCRIPTION')
                : t('CAMPAIGNS.EMPTY_DESCRIPTION')
            }}
          </p>
        </div>
        <Button
          v-if="!searchQuery"
          variant="outline"
          icon="i-lucide-plus"
          :label="t('CAMPAIGNS.NEW_CAMPAIGN')"
          @click="openNewCampaign"
        />
      </div>

      <!-- Campaign list -->
      <div v-else class="flex flex-col gap-3">
        <CampaignCard
          v-for="campaign in filteredCampaigns"
          :key="campaign.id"
          :campaign="campaign"
          @edit="handleEdit"
          @delete="handleDeleteRequest"
          @preview="handlePreview"
          @send-now="handleSendNowRequest"
        />
      </div>
    </div>
  </div>

  <Dialog
    ref="previewDialogRef"
    type="edit"
    :title="
      previewingCampaign
        ? previewingCampaign.name
        : t('CAMPAIGNS.PREVIEW.TITLE')
    "
    :show-confirm-button="false"
    width="sm"
    @close="previewingCampaign = null"
  >
    <NotificationTemplatePreview
      v-if="previewingCampaign"
      :messages="previewingCampaign.messages ?? []"
    />
  </Dialog>

  <Dialog
    ref="deleteDialogRef"
    type="alert"
    :title="t('CAMPAIGNS.DELETE.CONFIRM.TITLE')"
    :description="
      deletingCampaign
        ? t('CAMPAIGNS.DELETE.CONFIRM.MESSAGE', {
            name: deletingCampaign.name,
          })
        : ''
    "
    :confirm-button-label="t('CAMPAIGNS.DELETE.CONFIRM.YES')"
    :cancel-button-label="t('CAMPAIGNS.DELETE.CONFIRM.NO')"
    @confirm="confirmDelete"
  />

  <Dialog
    ref="sendDialogRef"
    type="alert"
    :title="t('CAMPAIGNS.CONFIRM_SEND')"
    :description="t('CAMPAIGNS.SEND_CONFIRM')"
    :confirm-button-label="t('CAMPAIGNS.SEND_NOW')"
    :cancel-button-label="t('CAMPAIGNS.CANCEL')"
    @confirm="confirmSendNow"
  />
</template>
