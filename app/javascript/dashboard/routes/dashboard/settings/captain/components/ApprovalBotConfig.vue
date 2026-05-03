<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ApprovalBotConfigAPI from 'dashboard/api/approvalBotConfig';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const { t } = useI18n();

const botToken = ref('');
const enabled = ref(false);
const botName = ref('');
const isExisting = ref(false);
const isSaving = ref(false);

async function fetchConfig() {
  try {
    const { data } = await ApprovalBotConfigAPI.get();
    const telegram = data.find(c => c.channel_type === 'telegram');
    if (telegram) {
      botToken.value = telegram.bot_token || '';
      enabled.value = telegram.enabled;
      botName.value = telegram.bot_name || '';
      isExisting.value = true;
    }
  } catch {
    // No config yet — that's fine
  }
}

async function saveConfig() {
  isSaving.value = true;
  try {
    const payload = {
      approval_bot_config: {
        channel_type: 'telegram',
        bot_token: botToken.value,
        enabled: enabled.value,
      },
    };

    if (isExisting.value) {
      await ApprovalBotConfigAPI.update('telegram', payload);
    } else {
      await ApprovalBotConfigAPI.create(payload);
      isExisting.value = true;
    }
    useAlert(t('CAPTAIN_SETTINGS.APPROVAL_BOT.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(
      error?.response?.data?.message ||
        t('CAPTAIN_SETTINGS.APPROVAL_BOT.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
}

onMounted(fetchConfig);
</script>

<template>
  <div class="flex flex-col gap-4">
    <Input
      v-model="botToken"
      type="password"
      :label="t('CAPTAIN_SETTINGS.APPROVAL_BOT.BOT_TOKEN_LABEL')"
      :placeholder="t('CAPTAIN_SETTINGS.APPROVAL_BOT.BOT_TOKEN_PLACEHOLDER')"
    />
    <p v-if="botName" class="text-sm text-n-text-body">
      {{ t('CAPTAIN_SETTINGS.APPROVAL_BOT.CONNECTED_AS', { name: botName }) }}
    </p>
    <label class="flex items-center gap-2 text-sm text-n-text-display">
      <input
        v-model="enabled"
        type="checkbox"
        class="rounded border-n-border-glass-soft"
      />
      {{ t('CAPTAIN_SETTINGS.APPROVAL_BOT.ENABLED_LABEL') }}
    </label>
    <div>
      <Button
        :label="t('CAPTAIN_SETTINGS.APPROVAL_BOT.SAVE')"
        :is-loading="isSaving"
        :disabled="isSaving || !botToken"
        @click="saveConfig"
      />
    </div>
  </div>
</template>
