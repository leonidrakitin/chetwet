<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useConfig } from 'dashboard/composables/useConfig';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['next']);
const { t } = useI18n();
const { currentAccount } = useAccount();
const { enabledLanguages } = useConfig();

const name = ref('');
const locale = ref('en');

const languageOptions = computed(() => {
  if (!enabledLanguages) return [];
  return [...enabledLanguages].sort((a, b) =>
    a.iso_639_1_code.localeCompare(b.iso_639_1_code)
  );
});

onMounted(() => {
  if (currentAccount.value) {
    name.value = currentAccount.value.name || '';
    locale.value = currentAccount.value.locale || 'en';
  }
});

function proceed() {
  if (!name.value.trim()) return;
  emit('next', { name: name.value.trim(), locale: locale.value });
}
</script>

<template>
  <div class="flex flex-col items-center text-center px-2">
    <div
      class="flex items-center justify-center w-16 h-16 rounded-2xl bg-n-brand/10 mb-6"
    >
      <Icon icon="i-lucide-building-2" class="size-8 text-n-brand" />
    </div>
    <h1 class="text-2xl font-bold text-n-slate-12 mb-2">
      {{ t('ONBOARDING.ACCOUNT_STEP.TITLE') }}
    </h1>
    <p class="text-sm text-n-slate-10 mb-8">
      {{ t('ONBOARDING.ACCOUNT_STEP.SUBTITLE') }}
    </p>
    <div class="w-full max-w-xs flex flex-col gap-4">
      <NextInput
        v-model="name"
        :label="t('ONBOARDING.ACCOUNT_STEP.NAME_LABEL')"
        :placeholder="t('ONBOARDING.ACCOUNT_STEP.NAME_PLACEHOLDER')"
        autofocus
        @enter="proceed"
      />
      <div>
        <label class="text-sm font-medium text-n-slate-11 mb-1.5 block">
          {{ t('ONBOARDING.ACCOUNT_STEP.LOCALE_LABEL') }}
        </label>
        <select
          v-model="locale"
          class="w-full rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-1 focus:ring-n-brand"
        >
          <option
            v-for="lang in languageOptions"
            :key="lang.iso_639_1_code"
            :value="lang.iso_639_1_code"
          >
            <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
            {{ `${lang.name} (${lang.iso_639_1_code})` }}
          </option>
        </select>
      </div>
      <NextButton
        class="mt-6 w-full"
        :label="isSaving ? t('ONBOARDING.SAVING') : t('ONBOARDING.NEXT')"
        :is-loading="isSaving"
        :disabled="!name.trim()"
        @click="proceed"
      />
    </div>
  </div>
</template>
