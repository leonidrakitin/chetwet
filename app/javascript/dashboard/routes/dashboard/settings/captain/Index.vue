<script setup>
import { useI18n } from 'vue-i18n';
import { useCaptain } from 'dashboard/composables/useCaptain';

import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SectionLayout from '../account/components/SectionLayout.vue';
import CaptainPaywall from 'next/captain/pageComponents/Paywall.vue';

const { t } = useI18n();
const { captainEnabled } = useCaptain();
</script>

<template>
  <SettingsLayout
    :is-loading="false"
    :no-records-message="t('CAPTAIN_SETTINGS.NOT_ENABLED')"
    :loading-message="t('CAPTAIN_SETTINGS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('CAPTAIN_SETTINGS.TITLE')"
        :description="t('CAPTAIN_SETTINGS.DESCRIPTION')"
        :link-text="t('CAPTAIN_SETTINGS.LINK_TEXT')"
        icon-name="captain"
        feature-name="captain_billing"
      />
    </template>
    <template #body>
      <div v-if="captainEnabled" class="flex flex-col gap-1">
        <SectionLayout
          :title="t('CAPTAIN_SETTINGS.MANAGED_IN_SUPER_ADMIN.TITLE')"
          :description="
            t('CAPTAIN_SETTINGS.MANAGED_IN_SUPER_ADMIN.DESCRIPTION')
          "
        />
      </div>
      <div v-else>
        <CaptainPaywall />
      </div>
    </template>
  </SettingsLayout>
</template>
