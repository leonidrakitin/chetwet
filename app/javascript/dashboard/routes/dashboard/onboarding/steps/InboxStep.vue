<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['next']);
const { t } = useI18n();

const channelType = ref('website');
const inboxName = ref('');
const websiteUrl = ref('');
const emailAddress = ref('');

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
];

function proceed() {
  if (!inboxName.value.trim()) return;
  const data = {
    channelType: channelType.value,
    inboxName: inboxName.value.trim(),
  };
  if (channelType.value === 'website') {
    data.websiteUrl = websiteUrl.value.trim();
  } else {
    data.emailAddress = emailAddress.value.trim();
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
    <h1 class="text-2xl font-bold text-n-slate-12 mb-2">
      {{ t('ONBOARDING.INBOX_STEP.TITLE') }}
    </h1>
    <p class="text-sm text-n-slate-10 mb-6">
      {{ t('ONBOARDING.INBOX_STEP.SUBTITLE') }}
    </p>

    <div class="w-full max-w-sm">
      <!-- Channel type selector -->
      <div class="flex gap-3 mb-6 justify-center">
        <button
          v-for="ch in CHANNELS"
          :key="ch.id"
          class="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium transition-all outline outline-1 -outline-offset-1"
          :class="
            channelType === ch.id
              ? 'bg-n-brand/10 text-n-brand outline-n-brand/30'
              : 'bg-white dark:bg-n-solid-3 text-n-slate-11 outline-n-container hover:outline-n-brand/30'
          "
          @click="channelType = ch.id"
        >
          <Icon :icon="ch.icon" class="size-4" />
          {{ t(ch.labelKey) }}
        </button>
      </div>

      <!-- Inbox name -->
      <div class="flex flex-col gap-4 text-left">
        <NextInput
          v-model="inboxName"
          :label="t('ONBOARDING.INBOX_STEP.NAME_LABEL')"
          :placeholder="t('ONBOARDING.INBOX_STEP.NAME_PLACEHOLDER')"
        />

        <!-- Website fields -->
        <NextInput
          v-if="channelType === 'website'"
          v-model="websiteUrl"
          :label="t('ONBOARDING.INBOX_STEP.URL_LABEL')"
          :placeholder="t('ONBOARDING.INBOX_STEP.URL_PLACEHOLDER')"
          @enter="proceed"
        />

        <!-- Email fields -->
        <NextInput
          v-if="channelType === 'email'"
          v-model="emailAddress"
          type="email"
          :label="t('ONBOARDING.INBOX_STEP.EMAIL_LABEL')"
          :placeholder="t('ONBOARDING.INBOX_STEP.EMAIL_PLACEHOLDER')"
          @enter="proceed"
        />
      </div>

      <NextButton
        class="mt-6 w-full"
        :label="isSaving ? t('ONBOARDING.SAVING') : t('ONBOARDING.NEXT')"
        :is-loading="isSaving"
        :disabled="!inboxName.trim()"
        @click="proceed"
      />
    </div>
  </div>
</template>
