<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  isSaving: { type: Boolean, default: false },
  lastError: { type: String, default: null },
});

const emit = defineEmits(['next', 'retry']);
const { t } = useI18n();

const channelType = ref('website');
const inboxName = ref('');
const websiteUrl = ref('');
const emailAddress = ref('');
const botToken = ref('');
const phoneNumber = ref('');
const webhookUrl = ref('');
const groupId = ref('');
const accessToken = ref('');
const clientId = ref('');
const clientSecret = ref('');

const CHANNELS = [
  {
    id: 'website',
    icon: 'i-lucide-globe',
    labelKey: 'ONBOARDING.INBOX_STEP.CHANNEL_WEBSITE',
  },
  {
    id: 'email',
    icon: 'i-lucide-mail',
    labelKey: 'ONBOARDING.INBOX_STEP.CHANNEL_EMAIL',
  },
  {
    id: 'telegram',
    icon: 'i-lucide-send',
    labelKey: 'ONBOARDING.INBOX_STEP.CHANNEL_TELEGRAM',
  },
  {
    id: 'whatsapp',
    icon: 'i-lucide-message-circle',
    labelKey: 'ONBOARDING.INBOX_STEP.CHANNEL_WHATSAPP',
  },
  {
    id: 'api',
    icon: 'i-lucide-cloud',
    labelKey: 'ONBOARDING.INBOX_STEP.CHANNEL_API',
  },
  {
    id: 'vk',
    icon: 'i-lucide-hash',
    labelKey: 'ONBOARDING.INBOX_STEP.CHANNEL_VK',
  },
  {
    id: 'avito',
    icon: 'i-lucide-shopping-bag',
    labelKey: 'ONBOARDING.INBOX_STEP.CHANNEL_AVITO',
  },
];

function checkCanProceed() {
  switch (channelType.value) {
    case 'website':
      return inboxName.value.trim();
    case 'email':
      return inboxName.value.trim() && emailAddress.value.trim();
    case 'telegram':
      return botToken.value.trim();
    case 'whatsapp':
      return inboxName.value.trim() && phoneNumber.value.trim();
    case 'api':
      return inboxName.value.trim();
    case 'vk':
      return accessToken.value.trim() && groupId.value.trim();
    case 'avito':
      return (
        inboxName.value.trim() &&
        clientId.value.trim() &&
        clientSecret.value.trim()
      );
    default:
      return false;
  }
}

function proceed() {
  if (!checkCanProceed()) return;

  const data = { channelType: channelType.value };

  switch (channelType.value) {
    case 'website':
      data.inboxName = inboxName.value.trim();
      data.websiteUrl = websiteUrl.value.trim();
      break;
    case 'email':
      data.inboxName = inboxName.value.trim();
      data.emailAddress = emailAddress.value.trim();
      break;
    case 'telegram':
      data.botToken = botToken.value.trim();
      break;
    case 'whatsapp':
      data.inboxName = inboxName.value.trim();
      data.phoneNumber = phoneNumber.value.trim();
      break;
    case 'api':
      data.inboxName = inboxName.value.trim();
      data.webhookUrl = webhookUrl.value.trim();
      break;
    case 'vk':
      data.accessToken = accessToken.value.trim();
      data.groupId = groupId.value.trim();
      break;
    case 'avito':
      data.inboxName = inboxName.value.trim();
      data.clientId = clientId.value.trim();
      data.clientSecret = clientSecret.value.trim();
      break;
    default:
      break;
  }

  emit('next', data);
}
</script>

<template>
  <div class="flex flex-col items-center text-center px-2">
    <div
      class="flex items-center justify-center w-16 h-16 rounded-2xl bg-n-brand/10 mb-6"
    >
      <Icon icon="i-lucide-inbox" class="size-8 text-n-brand" />
    </div>
    <h1 class="text-2xl font-bold text-n-text-display mb-2">
      {{ t('ONBOARDING.INBOX_STEP.TITLE') }}
    </h1>
    <p class="text-sm text-n-text-body/60 mb-6">
      {{ t('ONBOARDING.INBOX_STEP.SUBTITLE') }}
    </p>

    <div class="w-full max-w-sm">
      <!-- Channel type selector -->
      <div class="grid grid-cols-3 gap-2 mb-6">
        <button
          v-for="ch in CHANNELS"
          :key="ch.id"
          class="flex flex-col items-center gap-1.5 px-2 py-2.5 rounded-xl text-xs font-medium transition-all outline outline-1 -outline-offset-1"
          :class="
            channelType === ch.id
              ? 'bg-n-brand/10 text-n-brand outline-n-brand/30'
              : 'bg-white dark:bg-n-solid-3 text-n-text-body outline-n-border-glass-soft hover:outline-n-brand/30'
          "
          @click="channelType = ch.id"
        >
          <Icon :icon="ch.icon" class="size-4" />
          {{ t(ch.labelKey) }}
        </button>
      </div>

      <!-- Channel-specific fields -->
      <div class="flex flex-col gap-4 text-left">
        <!-- Website -->
        <template v-if="channelType === 'website'">
          <NextInput
            v-model="inboxName"
            :label="t('ONBOARDING.INBOX_STEP.NAME_LABEL')"
            :placeholder="t('ONBOARDING.INBOX_STEP.NAME_PLACEHOLDER')"
          />
          <NextInput
            v-model="websiteUrl"
            :label="t('ONBOARDING.INBOX_STEP.URL_LABEL')"
            :placeholder="t('ONBOARDING.INBOX_STEP.URL_PLACEHOLDER')"
            @enter="proceed"
          />
        </template>

        <!-- Email -->
        <template v-if="channelType === 'email'">
          <NextInput
            v-model="inboxName"
            :label="t('ONBOARDING.INBOX_STEP.NAME_LABEL')"
            :placeholder="t('ONBOARDING.INBOX_STEP.NAME_PLACEHOLDER')"
          />
          <NextInput
            v-model="emailAddress"
            type="email"
            :label="t('ONBOARDING.INBOX_STEP.EMAIL_LABEL')"
            :placeholder="t('ONBOARDING.INBOX_STEP.EMAIL_PLACEHOLDER')"
            @enter="proceed"
          />
        </template>

        <!-- Telegram -->
        <template v-if="channelType === 'telegram'">
          <NextInput
            v-model="botToken"
            :label="t('ONBOARDING.INBOX_STEP.BOT_TOKEN_LABEL')"
            :placeholder="t('ONBOARDING.INBOX_STEP.BOT_TOKEN_PLACEHOLDER')"
            @enter="proceed"
          />
          <p class="text-xs text-n-text-body/60 -mt-2">
            {{ t('ONBOARDING.INBOX_STEP.BOT_TOKEN_HELP') }}
            <a
              href="https://t.me/BotFather"
              target="_blank"
              rel="noopener noreferrer"
              class="text-n-brand hover:underline"
            >
              {{ t('ONBOARDING.INBOX_STEP.BOT_FATHER_LINK') }}
            </a>
          </p>
        </template>

        <!-- WhatsApp -->
        <template v-if="channelType === 'whatsapp'">
          <NextInput
            v-model="inboxName"
            :label="t('ONBOARDING.INBOX_STEP.NAME_LABEL')"
            :placeholder="t('ONBOARDING.INBOX_STEP.NAME_PLACEHOLDER')"
          />
          <NextInput
            v-model="phoneNumber"
            :label="t('ONBOARDING.INBOX_STEP.PHONE_LABEL')"
            :placeholder="t('ONBOARDING.INBOX_STEP.PHONE_PLACEHOLDER')"
            @enter="proceed"
          />
        </template>

        <!-- API -->
        <template v-if="channelType === 'api'">
          <NextInput
            v-model="inboxName"
            :label="t('ONBOARDING.INBOX_STEP.NAME_LABEL')"
            :placeholder="t('ONBOARDING.INBOX_STEP.NAME_PLACEHOLDER')"
          />
          <NextInput
            v-model="webhookUrl"
            :label="t('ONBOARDING.INBOX_STEP.WEBHOOK_LABEL')"
            :placeholder="t('ONBOARDING.INBOX_STEP.WEBHOOK_PLACEHOLDER')"
            @enter="proceed"
          />
        </template>

        <!-- VK -->
        <template v-if="channelType === 'vk'">
          <NextInput
            v-model="groupId"
            :label="t('ONBOARDING.INBOX_STEP.GROUP_ID_LABEL')"
            :placeholder="t('ONBOARDING.INBOX_STEP.GROUP_ID_PLACEHOLDER')"
          />
          <NextInput
            v-model="accessToken"
            :label="t('ONBOARDING.INBOX_STEP.ACCESS_TOKEN_LABEL')"
            :placeholder="t('ONBOARDING.INBOX_STEP.ACCESS_TOKEN_PLACEHOLDER')"
            @enter="proceed"
          />
          <p class="text-xs text-n-text-body/60 -mt-2">
            {{ t('ONBOARDING.INBOX_STEP.VK_TOKEN_HELP') }}
            <a
              href="https://dev.vk.com/api/bots/getting-started"
              target="_blank"
              rel="noopener noreferrer"
              class="text-n-brand hover:underline"
            >
              {{ t('ONBOARDING.INBOX_STEP.VK_DOCS_LINK') }}
            </a>
          </p>
        </template>

        <!-- Avito -->
        <template v-if="channelType === 'avito'">
          <NextInput
            v-model="inboxName"
            :label="t('ONBOARDING.INBOX_STEP.NAME_LABEL')"
            :placeholder="t('ONBOARDING.INBOX_STEP.NAME_PLACEHOLDER')"
          />
          <NextInput
            v-model="clientId"
            :label="t('ONBOARDING.INBOX_STEP.CLIENT_ID_LABEL')"
            :placeholder="t('ONBOARDING.INBOX_STEP.CLIENT_ID_PLACEHOLDER')"
          />
          <NextInput
            v-model="clientSecret"
            :label="t('ONBOARDING.INBOX_STEP.CLIENT_SECRET_LABEL')"
            :placeholder="t('ONBOARDING.INBOX_STEP.CLIENT_SECRET_PLACEHOLDER')"
            @enter="proceed"
          />
          <p class="text-xs text-n-text-body/60 -mt-2">
            {{ t('ONBOARDING.INBOX_STEP.AVITO_HELP') }}
            <a
              href="https://developers.avito.ru/"
              target="_blank"
              rel="noopener noreferrer"
              class="text-n-brand hover:underline"
            >
              {{ t('ONBOARDING.INBOX_STEP.AVITO_DOCS_LINK') }}
            </a>
          </p>
        </template>
      </div>

      <div
        v-if="lastError"
        class="flex items-center gap-2 rounded-lg bg-red-50 dark:bg-red-900/20 px-4 py-3 text-sm text-red-600 dark:text-red-400 mt-4"
      >
        <Icon icon="i-lucide-alert-circle" class="size-4 shrink-0" />
        <span class="flex-1">{{ lastError }}</span>
        <button
          class="text-xs underline hover:no-underline"
          @click="emit('retry')"
        >
          {{ t('ONBOARDING.RETRY') }}
        </button>
      </div>

      <NextButton
        class="mt-6 w-full"
        :label="isSaving ? t('ONBOARDING.SAVING') : t('ONBOARDING.NEXT')"
        :is-loading="isSaving"
        @click="proceed"
      />
    </div>
  </div>
</template>
