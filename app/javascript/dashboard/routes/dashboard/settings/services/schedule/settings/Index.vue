<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../../../SettingsLayout.vue';
import BaseSettingsHeader from '../../../components/BaseSettingsHeader.vue';
import AccountScheduleSettings from '../components/AccountScheduleSettings.vue';
import ProviderScheduleCard from '../components/ProviderScheduleCard.vue';
import ReportsPanel from '../components/ReportsPanel.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const store = useStore();
const { t } = useI18n();

const activeTab = ref('account');
const isLoading = ref(false);

const schedule = computed(() => store.getters['services/getSchedule']);
const providers = computed(() => store.getters['services/getProviders']);
const uiFlags = computed(() => store.getters['services/getUIFlags']);

const isUpdating = computed(() => uiFlags.value.isUpdatingSchedule);

const fetchAllData = async () => {
  isLoading.value = true;
  try {
    await Promise.all([
      store.dispatch('services/fetchSchedule'),
      store.dispatch('services/fetchProviders'),
    ]);
  } catch (error) {
    useAlert(error.message || t('SCHEDULE.SETTINGS.FETCH_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  fetchAllData();
});

const handleScheduleUpdate = async data => {
  try {
    if (schedule.value) {
      await store.dispatch('services/updateSchedule', data);
    } else {
      await store.dispatch('services/createSchedule', data);
    }
    useAlert(t('SCHEDULE.SETTINGS.UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(error.message || t('SCHEDULE.SETTINGS.UPDATE_ERROR'));
  }
};

const handleProviderScheduleUpdate = async ({ providerId, data }) => {
  try {
    await store.dispatch('services/updateProviderSchedule', {
      providerId,
      data,
    });
    useAlert(t('SCHEDULE.SETTINGS.UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(error.message || t('SCHEDULE.SETTINGS.UPDATE_ERROR'));
  }
};
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('SCHEDULE.SETTINGS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('SCHEDULE.SETTINGS.HEADER')"
        :description="$t('SCHEDULE.SETTINGS.DESCRIPTION')"
        feature-name="services_schedule"
      />
    </template>

    <template #body>
      <div class="flex flex-col gap-6">
        <div
          class="flex rounded-lg border border-n-border-glass-soft overflow-hidden w-fit"
        >
          <button
            class="px-4 py-2 text-sm font-medium transition-colors"
            :class="[
              activeTab === 'account'
                ? 'bg-n-brand text-white'
                : 'bg-n-glass-soft text-n-text-body hover:bg-n-glass-strong',
            ]"
            @click="activeTab = 'account'"
          >
            {{ t('SCHEDULE.SETTINGS.ACCOUNT_SCHEDULE') }}
          </button>
          <button
            class="px-4 py-2 text-sm font-medium transition-colors border-l border-n-border-glass-soft"
            :class="[
              activeTab === 'providers'
                ? 'bg-n-brand text-white'
                : 'bg-n-glass-soft text-n-text-body hover:bg-n-glass-strong',
            ]"
            @click="activeTab = 'providers'"
          >
            {{ t('SCHEDULE.SETTINGS.PROVIDER_SCHEDULES') }}
          </button>
          <button
            class="px-4 py-2 text-sm font-medium transition-colors border-l border-n-border-glass-soft"
            :class="[
              activeTab === 'reports'
                ? 'bg-n-brand text-white'
                : 'bg-n-glass-soft text-n-text-body hover:bg-n-glass-strong',
            ]"
            @click="activeTab = 'reports'"
          >
            {{ t('SCHEDULE.REPORTS.HEADER') }}
          </button>
        </div>

        <Spinner v-if="isLoading" class="m-auto" />

        <AccountScheduleSettings
          v-else-if="activeTab === 'account'"
          :schedule="schedule"
          :is-updating="isUpdating"
          @update="handleScheduleUpdate"
        />

        <div v-else-if="activeTab === 'providers'" class="flex flex-col gap-4">
          <ProviderScheduleCard
            v-for="provider in providers"
            :key="provider.id"
            :provider="provider"
            :account-schedule="schedule"
            :is-updating="isUpdating"
            @update="handleProviderScheduleUpdate"
          />
        </div>

        <ReportsPanel v-else-if="activeTab === 'reports'" />
      </div>
    </template>
  </SettingsLayout>
</template>
