<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useConfig } from 'dashboard/composables/useConfig';
import timeZoneData from 'dashboard/routes/dashboard/settings/inbox/helpers/timezones.json';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  isSaving: { type: Boolean, default: false },
  lastError: { type: String, default: null },
});

const emit = defineEmits(['next', 'retry']);
const { t } = useI18n();
const { currentAccount } = useAccount();
const { enabledLanguages } = useConfig();

const name = ref('');
const locale = ref('en');
const timezone = ref(Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC');

const languageOptions = computed(() => {
  if (!enabledLanguages) return [];
  return [...enabledLanguages].sort((a, b) =>
    a.iso_639_1_code.localeCompare(b.iso_639_1_code)
  );
});

const timezoneOptions = computed(() =>
  Object.entries(timeZoneData).map(([label, value]) => ({ label, value }))
);

onMounted(() => {
  if (currentAccount.value) {
    name.value = currentAccount.value.name || '';
    locale.value = currentAccount.value.locale || 'en';
    timezone.value =
      currentAccount.value.timezone ||
      Intl.DateTimeFormat().resolvedOptions().timeZone ||
      'UTC';
  }
});

function proceed() {
  if (!name.value.trim()) return;
  emit('next', {
    name: name.value.trim(),
    locale: locale.value,
    timezone: timezone.value,
  });
}
</script>

<template>
  <div class="flex flex-col items-center text-center px-2">
    <div
      class="flex items-center justify-center w-16 h-16 rounded-2xl bg-n-brand/10 mb-6"
    >
      <Icon icon="i-lucide-building-2" class="size-8 text-n-brand" />
    </div>
    <h1 class="text-2xl font-bold text-n-text-display mb-2">
      {{ t('ONBOARDING.ACCOUNT_STEP.TITLE') }}
    </h1>
    <p class="text-sm text-n-text-body/60 mb-8">
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
        <label class="text-sm font-medium text-n-text-body mb-1.5 block">
          {{ t('ONBOARDING.ACCOUNT_STEP.LOCALE_LABEL') }}
        </label>
        <select
          v-model="locale"
          class="w-full rounded-lg border border-n-border-glass-soft bg-white dark:bg-n-solid-3 px-3 py-2 text-sm text-n-text-display outline-none focus:border-n-brand focus:ring-1 focus:ring-n-brand"
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
      <div>
        <label class="text-sm font-medium text-n-text-body mb-1.5 block">
          {{ t('ONBOARDING.ACCOUNT_STEP.TIMEZONE_LABEL') }}
        </label>
        <select
          v-model="timezone"
          class="w-full rounded-lg border border-n-border-glass-soft bg-white dark:bg-n-solid-3 px-3 py-2 text-sm text-n-text-display outline-none focus:border-n-brand focus:ring-1 focus:ring-n-brand"
        >
          <option
            v-for="tz in timezoneOptions"
            :key="tz.value"
            :value="tz.value"
          >
            <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
            {{ tz.label }}
          </option>
        </select>
      </div>

      <div
        v-if="lastError"
        class="flex items-center gap-2 rounded-lg bg-red-50 dark:bg-red-900/20 px-4 py-3 text-sm text-red-600 dark:text-red-400"
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
        :disabled="!name.trim()"
        @click="proceed"
      />
    </div>
  </div>
</template>
