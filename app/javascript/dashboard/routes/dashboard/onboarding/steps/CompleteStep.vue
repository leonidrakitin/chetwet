<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  profileSet: { type: Boolean, default: false },
  agentsInvited: { type: Number, default: 0 },
  inboxCreated: { type: Boolean, default: false },
  greetingSet: { type: Boolean, default: false },
  cannedResponsesCreated: { type: Number, default: 0 },
});

const emit = defineEmits(['finish']);
const { t } = useI18n();

const hasAnySetup = computed(() => {
  return (
    props.profileSet ||
    props.agentsInvited > 0 ||
    props.inboxCreated ||
    props.greetingSet ||
    props.cannedResponsesCreated > 0
  );
});
</script>

<template>
  <div class="flex flex-col items-center text-center px-2">
    <div
      class="flex items-center justify-center w-16 h-16 rounded-2xl bg-green-500/10 mb-6"
    >
      <Icon icon="i-lucide-check-circle" class="size-8 text-green-500" />
    </div>
    <h1 class="text-2xl font-bold text-n-text-display mb-2">
      {{ t('ONBOARDING.COMPLETE_STEP.TITLE') }}
    </h1>
    <p class="text-sm text-n-text-body/60 mb-8">
      {{ t('ONBOARDING.COMPLETE_STEP.SUBTITLE') }}
    </p>

    <!-- Summary -->
    <div v-if="hasAnySetup" class="flex flex-col gap-2 w-full max-w-xs mb-8">
      <div
        v-if="profileSet"
        class="flex items-center gap-3 rounded-lg bg-n-alpha-1 px-4 py-2.5 text-sm text-n-text-body"
      >
        <Icon icon="i-lucide-check" class="size-4 text-green-500 shrink-0" />
        {{ t('ONBOARDING.COMPLETE_STEP.SUMMARY_PROFILE') }}
      </div>
      <div
        v-if="agentsInvited > 0"
        class="flex items-center gap-3 rounded-lg bg-n-alpha-1 px-4 py-2.5 text-sm text-n-text-body"
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
        class="flex items-center gap-3 rounded-lg bg-n-alpha-1 px-4 py-2.5 text-sm text-n-text-body"
      >
        <Icon icon="i-lucide-check" class="size-4 text-green-500 shrink-0" />
        {{ t('ONBOARDING.COMPLETE_STEP.SUMMARY_INBOX') }}
      </div>
      <div
        v-if="greetingSet"
        class="flex items-center gap-3 rounded-lg bg-n-alpha-1 px-4 py-2.5 text-sm text-n-text-body"
      >
        <Icon icon="i-lucide-check" class="size-4 text-green-500 shrink-0" />
        {{ t('ONBOARDING.COMPLETE_STEP.SUMMARY_GREETING') }}
      </div>
      <div
        v-if="cannedResponsesCreated > 0"
        class="flex items-center gap-3 rounded-lg bg-n-alpha-1 px-4 py-2.5 text-sm text-n-text-body"
      >
        <Icon icon="i-lucide-check" class="size-4 text-green-500 shrink-0" />
        {{
          t('ONBOARDING.COMPLETE_STEP.SUMMARY_CANNED', {
            count: cannedResponsesCreated,
          })
        }}
      </div>
    </div>

    <div v-else class="flex flex-col items-center gap-4 mb-8">
      <div
        class="flex items-center gap-3 rounded-lg bg-n-alpha-1 px-4 py-2.5 text-sm text-n-text-body"
      >
        <Icon icon="i-lucide-rocket" class="size-4 text-n-brand shrink-0" />
        {{ t('ONBOARDING.COMPLETE_STEP.QUICK_START') }}
      </div>
      <p class="text-xs text-n-slate-9 max-w-xs">
        {{ t('ONBOARDING.COMPLETE_STEP.SETUP_LATER_HINT') }}
      </p>
      <a
        href="https://www.chatwoot.com/docs"
        target="_blank"
        rel="noopener noreferrer"
        class="text-xs text-n-brand hover:underline"
      >
        {{ t('ONBOARDING.COMPLETE_STEP.DOCS_LINK') }}
      </a>
    </div>

    <NextButton
      :label="t('ONBOARDING.COMPLETE_STEP.GO_TO_DASHBOARD')"
      icon="i-lucide-arrow-right"
      @click="emit('finish')"
    />
  </div>
</template>
