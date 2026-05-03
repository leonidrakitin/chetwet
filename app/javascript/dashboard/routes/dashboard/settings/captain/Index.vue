<script setup>
import { useI18n } from 'vue-i18n';
import { useCaptain } from 'dashboard/composables/useCaptain';
import { useCaptainConfigStore } from 'dashboard/store/captain/preferences';

import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SectionLayout from '../account/components/SectionLayout.vue';
import CaptainPaywall from 'next/captain/pageComponents/Paywall.vue';

const { t } = useI18n();
const { captainEnabled } = useCaptain();
const captainConfigStore = useCaptainConfigStore();

const enabledProviders = captainConfigStore.getEnabledProviders;
const primaryProvider = captainConfigStore.getPrimaryProvider;

const providerNames = {
  openai: 'OpenAI',
  openrouter: 'OpenRouter',
  anthropic: 'Anthropic',
  gemini: 'Google Gemini',
  deepseek: 'DeepSeek',
  qwen: 'Qwen',
  zai: 'Z.AI',
  ollama: 'Ollama',
};
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
      <div v-if="captainEnabled" class="flex flex-col gap-6">
        <SectionLayout
          :title="t('CAPTAIN_SETTINGS.PROVIDER_STATUS.TITLE')"
          :description="t('CAPTAIN_SETTINGS.PROVIDER_STATUS.DESCRIPTION')"
        >
          <div class="flex flex-wrap gap-3 mt-4">
            <div
              v-for="provider in enabledProviders"
              :key="provider"
              class="px-3 py-2 rounded-lg text-sm font-medium"
              :class="
                provider === primaryProvider
                  ? 'bg-n-teal-3 text-n-teal-12 dark:bg-n-teal-9 dark:text-n-teal-3'
                  : 'bg-n-slate-3 text-n-text-display dark:bg-n-solid-3 dark:text-n-text-body'
              "
            >
              {{ providerNames[provider] || provider }}
              <span v-if="provider === primaryProvider" class="ml-1 text-xs">{{
                t('CAPTAIN_SETTINGS.PROVIDER_STATUS.PRIMARY')
              }}</span>
            </div>
            <div
              v-if="enabledProviders.length === 0"
              class="px-3 py-2 rounded-lg text-sm bg-n-amber-3 text-n-amber-12"
            >
              {{ t('CAPTAIN_SETTINGS.PROVIDER_STATUS.NO_PROVIDERS') }}
            </div>
          </div>
        </SectionLayout>

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
