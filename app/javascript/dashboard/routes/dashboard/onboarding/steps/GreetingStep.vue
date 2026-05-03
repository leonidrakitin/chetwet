<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  isSaving: { type: Boolean, default: false },
  lastError: { type: String, default: null },
});

const emit = defineEmits(['next', 'retry']);
const { t } = useI18n();

const greetingEnabled = ref(true);
const greetingMessage = ref('');

const MAX_LENGTH = 1000;
const charCount = computed(() => greetingMessage.value.length);
const isOverLimit = computed(() => charCount.value > MAX_LENGTH);

const previewMessage = computed(() => {
  if (!greetingMessage.value.trim()) {
    return t('ONBOARDING.GREETING_STEP.MESSAGE_PLACEHOLDER');
  }
  return greetingMessage.value;
});

function proceed() {
  emit('next', {
    greetingEnabled: greetingEnabled.value,
    greetingMessage: greetingMessage.value.trim(),
  });
}
</script>

<template>
  <div class="flex flex-col items-center text-center px-2">
    <div
      class="flex items-center justify-center w-16 h-16 rounded-2xl bg-n-brand/10 mb-6"
    >
      <Icon icon="i-lucide-message-square" class="size-8 text-n-brand" />
    </div>
    <h1 class="text-2xl font-bold text-n-text-display mb-2">
      {{ t('ONBOARDING.GREETING_STEP.TITLE') }}
    </h1>
    <p class="text-sm text-n-text-body/60 mb-2">
      {{ t('ONBOARDING.GREETING_STEP.SUBTITLE') }}
    </p>
    <p class="text-xs text-n-slate-9 mb-6">
      {{ t('ONBOARDING.GREETING_STEP.WEBSITE_ONLY') }}
    </p>

    <div class="w-full max-w-sm">
      <!-- Toggle -->
      <div class="flex items-center justify-between mb-4">
        <label class="text-sm font-medium text-n-text-body">
          {{ t('ONBOARDING.GREETING_STEP.ENABLED_LABEL') }}
        </label>
        <button
          class="relative w-10 h-5 rounded-full transition-colors"
          :class="greetingEnabled ? 'bg-n-brand' : 'bg-n-slate-5'"
          @click="greetingEnabled = !greetingEnabled"
        >
          <span
            class="absolute top-0.5 left-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform"
            :class="greetingEnabled ? 'translate-x-5' : 'translate-x-0'"
          />
        </button>
      </div>

      <!-- Message textarea + Preview -->
      <div v-if="greetingEnabled" class="text-left">
        <label class="text-sm font-medium text-n-text-body mb-1.5 block">
          {{ t('ONBOARDING.GREETING_STEP.MESSAGE_LABEL') }}
        </label>
        <textarea
          v-model="greetingMessage"
          :placeholder="t('ONBOARDING.GREETING_STEP.MESSAGE_PLACEHOLDER')"
          rows="3"
          class="w-full rounded-lg border border-n-border-glass-soft bg-white dark:bg-n-solid-3 px-3 py-2 text-sm text-n-text-display outline-none focus:border-n-brand focus:ring-1 focus:ring-n-brand placeholder:text-n-slate-8 resize-none"
          :class="{ 'border-red-400': isOverLimit }"
        />
        <div class="flex justify-between items-center mt-1">
          <span class="text-xs text-n-slate-9">
            {{ t('ONBOARDING.GREETING_STEP.PREVIEW_HINT') }}
          </span>
          <span
            class="text-xs"
            :class="isOverLimit ? 'text-red-500' : 'text-n-slate-9'"
          >
            {{ charCount }} / {{ MAX_LENGTH }}
          </span>
        </div>

        <!-- Preview bubble -->
        <div
          class="mt-4 p-3 bg-n-glass-soft rounded-lg border border-n-border-glass-soft"
        >
          <p class="text-xs text-n-slate-9 mb-2">
            {{ t('ONBOARDING.GREETING_STEP.PREVIEW_LABEL') }}
          </p>
          <div
            class="bg-n-brand text-white text-sm px-3 py-2 rounded-xl rounded-br-sm max-w-xs"
          >
            {{ previewMessage }}
          </div>
        </div>
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
        :disabled="isOverLimit"
        @click="proceed"
      />
    </div>
  </div>
</template>
