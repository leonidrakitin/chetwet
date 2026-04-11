<script setup>
import { useAlert } from 'dashboard/composables';
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { picoSearch } from '@scmmishra/pico-search';

import AddProvider from './AddProvider.vue';
import AddService from './AddService.vue';
import EditProvider from './EditProvider.vue';
import EditService from './EditService.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

const loading = ref({});
const activeTab = ref('providers');
const showAddProviderPopup = ref(false);
const showAddServicePopup = ref(false);
const showEditProviderPopup = ref(false);
const showEditServicePopup = ref(false);
const showDeletePopup = ref(false);
const selectedItem = ref({});
const searchQuery = ref('');

const providers = computed(() => getters['services/getProviders'].value);
const services = computed(() => getters['services/getServices'].value);
const uiFlags = computed(() => getters['services/getUIFlags'].value);

const currentRecords = computed(() => {
  return activeTab.value === 'providers' ? providers.value : services.value;
});

const filteredRecords = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return currentRecords.value;
  return picoSearch(currentRecords.value, query, ['name', 'description']);
});

const deleteMessage = computed(() => ` ${selectedItem.value.name}?`);

const openAddProviderPopup = () => {
  showAddProviderPopup.value = true;
};
const hideAddProviderPopup = () => {
  showAddProviderPopup.value = false;
};

const openAddServicePopup = () => {
  showAddServicePopup.value = true;
};
const hideAddServicePopup = () => {
  showAddServicePopup.value = false;
};

const openEditProviderPopup = item => {
  selectedItem.value = item;
  showEditProviderPopup.value = true;
};
const hideEditProviderPopup = () => {
  showEditProviderPopup.value = false;
};

const openEditServicePopup = item => {
  selectedItem.value = item;
  showEditServicePopup.value = true;
};
const hideEditServicePopup = () => {
  showEditServicePopup.value = false;
};

const openDeletePopup = item => {
  selectedItem.value = item;
  showDeletePopup.value = true;
};
const closeDeletePopup = () => {
  showDeletePopup.value = false;
};

const deleteItem = async () => {
  loading.value[selectedItem.value.id] = true;
  try {
    const action =
      activeTab.value === 'providers'
        ? 'services/deleteProvider'
        : 'services/deleteService';
    await store.dispatch(action, selectedItem.value.id);
    useAlert(t('SERVICES_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    const errorMessage =
      error?.message || t('SERVICES_MGMT.DELETE.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  } finally {
    loading.value[selectedItem.value.id] = false;
  }
};

const confirmDeletion = () => {
  closeDeletePopup();
  deleteItem();
};

const switchTab = tab => {
  activeTab.value = tab;
  searchQuery.value = '';
};

const tableHeaders = computed(() => {
  if (activeTab.value === 'providers') {
    return [
      t('SERVICES_MGMT.PROVIDERS.TABLE_HEADER.NAME'),
      t('SERVICES_MGMT.PROVIDERS.TABLE_HEADER.STATUS'),
      t('SERVICES_MGMT.PROVIDERS.TABLE_HEADER.ACTION'),
    ];
  }
  return [
    t('SERVICES_MGMT.SERVICES.TABLE_HEADER.NAME'),
    t('SERVICES_MGMT.SERVICES.TABLE_HEADER.DURATION'),
    t('SERVICES_MGMT.SERVICES.TABLE_HEADER.PRICE'),
    t('SERVICES_MGMT.SERVICES.TABLE_HEADER.ACTION'),
  ];
});

const isFetching = computed(() => {
  return uiFlags.value.isFetchingProviders || uiFlags.value.isFetchingServices;
});

onBeforeMount(() => {
  store.dispatch('services/fetchProviders');
  store.dispatch('services/fetchServices');
});
</script>

<template>
  <SettingsLayout
    :is-loading="isFetching"
    :loading-message="$t('SERVICES_MGMT.LOADING')"
    :no-records-found="!currentRecords.length"
    :no-records-message="$t('SERVICES_MGMT.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('SERVICES_MGMT.HEADER')"
        :description="$t('SERVICES_MGMT.DESCRIPTION')"
        :search-placeholder="$t('SERVICES_MGMT.SEARCH_PLACEHOLDER')"
        feature-name="services"
      >
        <template v-if="currentRecords?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('SERVICES_MGMT.COUNT', { n: currentRecords.length }) }}
          </span>
        </template>
        <template #actions>
          <Button
            v-if="activeTab === 'providers'"
            :label="$t('SERVICES_MGMT.PROVIDERS.ADD_BUTTON')"
            size="sm"
            @click="openAddProviderPopup"
          />
          <Button
            v-else
            :label="$t('SERVICES_MGMT.SERVICES.ADD_BUTTON')"
            size="sm"
            @click="openAddServicePopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="flex gap-2 mb-4">
        <Button
          :label="$t('SERVICES_MGMT.TABS.PROVIDERS')"
          :class="{ 'bg-n-brand-1 text-white': activeTab === 'providers' }"
          faded
          slate
          size="sm"
          @click="switchTab('providers')"
        />
        <Button
          :label="$t('SERVICES_MGMT.TABS.SERVICES')"
          :class="{ 'bg-n-brand-1 text-white': activeTab === 'services' }"
          faded
          slate
          size="sm"
          @click="switchTab('services')"
        />
      </div>

      <BaseTable
        :headers="tableHeaders"
        :items="filteredRecords"
        :no-data-message="
          searchQuery
            ? $t('SERVICES_MGMT.NO_RESULTS')
            : $t('SERVICES_MGMT.LIST.404')
        "
      >
        <template #row="{ items }">
          <BaseTableRow v-for="item in items" :key="item.id" :item="item">
            <template #default>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-12">
                  {{ item.name }}
                </span>
              </BaseTableCell>

              <BaseTableCell v-if="activeTab === 'providers'">
                <span
                  :class="
                    item.active
                      ? 'text-n-teal-11 bg-n-teal-2'
                      : 'text-n-ruby-11 bg-n-ruby-2'
                  "
                  class="px-2 py-1 rounded-md text-xs font-medium"
                >
                  {{
                    item.active
                      ? $t('SERVICES_MGMT.STATUS.ACTIVE')
                      : $t('SERVICES_MGMT.STATUS.INACTIVE')
                  }}
                </span>
              </BaseTableCell>

              <BaseTableCell v-if="activeTab === 'services'">
                <span class="text-body-main text-n-slate-11">
                  {{
                    item.formatted_duration ||
                    `${item.duration_minutes} ${$t('SERVICES_MGMT.DURATION.MIN')}`
                  }}
                </span>
              </BaseTableCell>

              <BaseTableCell v-if="activeTab === 'services'">
                <span class="text-body-main text-n-slate-11">
                  {{
                    item.price
                      ? `${item.price} ${item.currency}`
                      : $t('SERVICES_MGMT.PRICE.NOT_SET')
                  }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="$t('SERVICES_MGMT.FORM.EDIT')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    :is-loading="loading[item.id]"
                    @click="
                      activeTab === 'providers'
                        ? openEditProviderPopup(item)
                        : openEditServicePopup(item)
                    "
                  />
                  <Button
                    v-tooltip.top="$t('SERVICES_MGMT.FORM.DELETE')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :is-loading="loading[item.id]"
                    @click="openDeletePopup(item)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal
      v-model:show="showAddProviderPopup"
      :on-close="hideAddProviderPopup"
    >
      <AddProvider @close="hideAddProviderPopup" />
    </woot-modal>

    <woot-modal
      v-model:show="showAddServicePopup"
      :on-close="hideAddServicePopup"
    >
      <AddService @close="hideAddServicePopup" />
    </woot-modal>

    <woot-modal
      v-model:show="showEditProviderPopup"
      :on-close="hideEditProviderPopup"
    >
      <EditProvider
        :selected-provider="selectedItem"
        @close="hideEditProviderPopup"
      />
    </woot-modal>

    <woot-modal
      v-model:show="showEditServicePopup"
      :on-close="hideEditServicePopup"
    >
      <EditService
        :selected-service="selectedItem"
        @close="hideEditServicePopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeletePopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('SERVICES_MGMT.DELETE.CONFIRM.TITLE')"
      :message="$t('SERVICES_MGMT.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="$t('SERVICES_MGMT.DELETE.CONFIRM.YES')"
      :reject-text="$t('SERVICES_MGMT.DELETE.CONFIRM.NO')"
    />
  </SettingsLayout>
</template>
