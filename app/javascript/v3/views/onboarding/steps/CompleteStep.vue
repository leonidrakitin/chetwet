<script setup>
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['finish']);
const { t } = useI18n();
</script>

<template>
  <div class="flex flex-col items-center text-center px-2">
    <div
      class="flex items-center justify-center w-16 h-16 rounded-full bg-n-teal-3 mb-6"
    >
      <Icon icon="i-lucide-check" class="size-8 text-n-teal-11" />
    </div>
    <h1 class="text-2xl font-bold text-n-slate-12 mb-2">
      {{ t('ONBOARDING_WIZARD.COMPLETE_TITLE') }}
    </h1>
    <p class="text-sm text-n-slate-10 mb-8">
      {{ t('ONBOARDING_WIZARD.COMPLETE_SUBTITLE') }}
    </p>
    <NextButton
      :label="t('ONBOARDING_WIZARD.GO_TO_DASHBOARD')"
      @click="emit('finish')"
    />
  </div>
</template>
