<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { storeToRefs } from 'pinia';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useCaptain } from 'dashboard/composables/useCaptain';
import { useConfig } from 'dashboard/composables/useConfig';
import { useCaptainConfigStore } from 'dashboard/store/captain/preferences';

import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SectionLayout from '../account/components/SectionLayout.vue';
import ModelSelector from './components/ModelSelector.vue';
import CaptainPaywall from 'next/captain/pageComponents/Paywall.vue';
import ApprovalBotConfig from './components/ApprovalBotConfig.vue';

const { t } = useI18n();
const { captainEnabled } = useCaptain();
const { isEnterprise } = useConfig();
const { isOnChatwootCloud } = useAccount();

const captainConfigStore = useCaptainConfigStore();
const { uiFlags, messageBufferSeconds } = storeToRefs(captainConfigStore);
const bufferSecondsInput = ref(4);
watch(
  messageBufferSeconds,
  val => {
    bufferSecondsInput.value = val;
  },
  { immediate: true }
);

const isLoading = computed(() => uiFlags.value.isFetching);

const modelFeatures = computed(() => [
  {
    key: 'editor',
    title: t('CAPTAIN_SETTINGS.MODEL_CONFIG.EDITOR.TITLE'),
    description: t('CAPTAIN_SETTINGS.MODEL_CONFIG.EDITOR.DESCRIPTION'),
  },
  {
    key: 'assistant',
    title: t('CAPTAIN_SETTINGS.MODEL_CONFIG.ASSISTANT.TITLE'),
    description: t('CAPTAIN_SETTINGS.MODEL_CONFIG.ASSISTANT.DESCRIPTION'),
    enterprise: true,
  },
  {
    key: 'copilot',
    title: t('CAPTAIN_SETTINGS.MODEL_CONFIG.COPILOT.TITLE'),
    description: t('CAPTAIN_SETTINGS.MODEL_CONFIG.COPILOT.DESCRIPTION'),
    enterprise: true,
  },
]);

const shouldShowFeature = feature => {
  // Cloud will always see these features as long as captain is enabled
  if (isOnChatwootCloud.value && captainEnabled) {
    return true;
  }

  if (feature.enterprise) {
    // if the app is in enterprise mode, then we can show the feature
    // this is not the installation plan, but when the enterprise folder is missing
    return isEnterprise;
  }

  return true;
};

const isFeatureAccessible = feature => {
  if (feature.enterprise) {
    return isEnterprise;
  }

  return true;
};

async function handleModelChange({ feature, model }) {
  try {
    await captainConfigStore.updatePreferences({
      captain_models: { [feature]: model },
    });
    useAlert(t('CAPTAIN_SETTINGS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('CAPTAIN_SETTINGS.API.ERROR'));
    captainConfigStore.fetch();
  }
}

function clampBufferSeconds(value) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.min(30, Math.max(1, Math.round(n))) : 4;
}

async function handleMessageBufferChange(value) {
  const seconds = clampBufferSeconds(value);
  try {
    await captainConfigStore.updatePreferences({
      message_buffer_seconds: seconds,
    });
    useAlert(t('CAPTAIN_SETTINGS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('CAPTAIN_SETTINGS.API.ERROR'));
    captainConfigStore.fetch();
  }
}

onMounted(() => {
  captainConfigStore.fetch();
});
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
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
        <!-- Model Configuration Section -->
        <SectionLayout
          :title="t('CAPTAIN_SETTINGS.MODEL_CONFIG.TITLE')"
          :description="t('CAPTAIN_SETTINGS.MODEL_CONFIG.DESCRIPTION')"
        >
          <div class="grid gap-4">
            <ModelSelector
              v-for="feature in modelFeatures"
              v-show="shouldShowFeature(feature)"
              :key="feature.key"
              :is-allowed="isFeatureAccessible(feature)"
              :feature-key="feature.key"
              :title="feature.title"
              :description="feature.description"
              @change="handleModelChange"
            />
          </div>
        </SectionLayout>

        <!-- Message buffer -->
        <SectionLayout
          :title="t('CAPTAIN_SETTINGS.MESSAGE_BUFFER.TITLE')"
          :description="t('CAPTAIN_SETTINGS.MESSAGE_BUFFER.DESCRIPTION')"
          with-border
        >
          <div class="flex flex-col gap-2">
            <div class="flex items-center gap-4">
              <input
                v-model.number="bufferSecondsInput"
                type="range"
                min="1"
                max="30"
                step="1"
                class="w-full max-w-xs h-2 rounded-lg appearance-none cursor-pointer bg-n-weak accent-n-blue-11"
                @change="handleMessageBufferChange(bufferSecondsInput)"
              />
              <span class="text-sm font-medium text-n-slate-12 shrink-0 w-10">
                {{
                  $t('CAPTAIN_SETTINGS.MESSAGE_BUFFER.SECONDS', {
                    count: bufferSecondsInput,
                  })
                }}
              </span>
            </div>
          </div>
        </SectionLayout>
        <!-- Approval Bot -->
        <SectionLayout
          :title="t('CAPTAIN_SETTINGS.APPROVAL_BOT.TITLE')"
          :description="t('CAPTAIN_SETTINGS.APPROVAL_BOT.DESCRIPTION')"
          with-border
        >
          <ApprovalBotConfig />
        </SectionLayout>
      </div>
      <div v-else>
        <CaptainPaywall />
      </div>
    </template>
  </SettingsLayout>
</template>
