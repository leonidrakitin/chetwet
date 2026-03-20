<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['next']);
const { t } = useI18n();

const greetingEnabled = ref(true);
const greetingMessage = ref('');

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
    <h1 class="text-2xl font-bold text-n-slate-12 mb-2">
      {{ t('ONBOARDING.GREETING_STEP.TITLE') }}
    </h1>
    <p class="text-sm text-n-slate-10 mb-6">
      {{ t('ONBOARDING.GREETING_STEP.SUBTITLE') }}
    </p>

    <div class="w-full max-w-sm">
      <!-- Toggle -->
      <div class="flex items-center justify-between mb-4">
        <label class="text-sm font-medium text-n-slate-11">
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

      <!-- Message textarea -->
      <div v-if="greetingEnabled" class="text-left">
        <label class="text-sm font-medium text-n-slate-11 mb-1.5 block">
          {{ t('ONBOARDING.GREETING_STEP.MESSAGE_LABEL') }}
        </label>
        <textarea
          v-model="greetingMessage"
          :placeholder="t('ONBOARDING.GREETING_STEP.MESSAGE_PLACEHOLDER')"
          rows="3"
          class="w-full rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-1 focus:ring-n-brand placeholder:text-n-slate-8 resize-none"
        />
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
