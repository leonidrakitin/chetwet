<script setup>
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

defineProps({
  profileSet: { type: Boolean, default: false },
  agentsInvited: { type: Number, default: 0 },
  inboxCreated: { type: Boolean, default: false },
  greetingSet: { type: Boolean, default: false },
  cannedResponsesCreated: { type: Number, default: 0 },
});

const emit = defineEmits(['finish']);
const { t } = useI18n();
</script>

<template>
  <div class="flex flex-col items-center text-center px-2">
    <div
      class="flex items-center justify-center w-16 h-16 rounded-2xl bg-green-500/10 mb-6"
    >
      <Icon icon="i-lucide-check-circle" class="size-8 text-green-500" />
    </div>
    <h1 class="text-2xl font-bold text-n-slate-12 mb-2">
      {{ t('ONBOARDING.COMPLETE_STEP.TITLE') }}
    </h1>
    <p class="text-sm text-n-slate-10 mb-8">
      {{ t('ONBOARDING.COMPLETE_STEP.SUBTITLE') }}
    </p>

    <!-- Summary -->
    <div class="flex flex-col gap-2 w-full max-w-xs mb-8">
      <div
        v-if="profileSet"
        class="flex items-center gap-3 rounded-lg bg-n-alpha-1 px-4 py-2.5 text-sm text-n-slate-11"
      >
        <Icon icon="i-lucide-check" class="size-4 text-green-500 shrink-0" />
        {{ t('ONBOARDING.COMPLETE_STEP.SUMMARY_PROFILE') }}
      </div>
      <div
        class="flex items-center gap-3 rounded-lg bg-n-alpha-1 px-4 py-2.5 text-sm text-n-slate-11"
      >
        <Icon icon="i-lucide-check" class="size-4 text-green-500 shrink-0" />
        {{ t('ONBOARDING.COMPLETE_STEP.SUMMARY_ACCOUNT') }}
      </div>
      <div
        v-if="agentsInvited > 0"
        class="flex items-center gap-3 rounded-lg bg-n-alpha-1 px-4 py-2.5 text-sm text-n-slate-11"
      >
        <Icon icon="i-lucide-check" class="size-4 text-green-500 shrink-0" />
        {{
          t('ONBOARDING.COMPLETE_STEP.SUMMARY_AGENTS', {
            count: agentsInvited,
          })
        }}
      </div>
      <div
        v-if="inboxCreated"
        class="flex items-center gap-3 rounded-lg bg-n-alpha-1 px-4 py-2.5 text-sm text-n-slate-11"
      >
        <Icon icon="i-lucide-check" class="size-4 text-green-500 shrink-0" />
        {{ t('ONBOARDING.COMPLETE_STEP.SUMMARY_INBOX') }}
      </div>
      <div
        v-if="greetingSet"
        class="flex items-center gap-3 rounded-lg bg-n-alpha-1 px-4 py-2.5 text-sm text-n-slate-11"
      >
        <Icon icon="i-lucide-check" class="size-4 text-green-500 shrink-0" />
        {{ t('ONBOARDING.COMPLETE_STEP.SUMMARY_GREETING') }}
      </div>
      <div
        v-if="cannedResponsesCreated > 0"
        class="flex items-center gap-3 rounded-lg bg-n-alpha-1 px-4 py-2.5 text-sm text-n-slate-11"
      >
        <Icon icon="i-lucide-check" class="size-4 text-green-500 shrink-0" />
        {{
          t('ONBOARDING.COMPLETE_STEP.SUMMARY_CANNED', {
            count: cannedResponsesCreated,
          })
        }}
      </div>
    </div>

    <NextButton
      :label="t('ONBOARDING.COMPLETE_STEP.GO_TO_DASHBOARD')"
      icon="i-lucide-arrow-right"
      @click="emit('finish')"
    />
  </div>
</template>
