<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  isSaving: { type: Boolean, default: false },
  lastError: { type: String, default: null },
});

const emit = defineEmits(['next', 'retry']);
const { t } = useI18n();
const store = useStore();

const displayName = ref('');
const touched = ref(false);

const displayNameError = computed(() => {
  if (!touched.value) return null;
  if (!displayName.value.trim()) {
    return t('ONBOARDING.PROFILE_STEP.NAME_REQUIRED');
  }
  if (displayName.value.trim().length < 2) {
    return t('ONBOARDING.PROFILE_STEP.NAME_TOO_SHORT');
  }
  return null;
});

const canProceed = computed(() => {
  return displayName.value.trim().length >= 2;
});

onMounted(() => {
  const user = store.getters['auth/getCurrentUser'];
  displayName.value = user?.display_name || user?.name || '';
});

function handleBlur() {
  touched.value = true;
}

function proceed() {
  touched.value = true;
  if (!canProceed.value) return;
  emit('next', { displayName: displayName.value.trim() });
}
</script>

<template>
  <div class="flex flex-col items-center text-center px-2">
    <div
      class="flex items-center justify-center w-16 h-16 rounded-2xl bg-n-brand/10 mb-6"
    >
      <Icon icon="i-lucide-user" class="size-8 text-n-brand" />
    </div>
    <h1 class="text-2xl font-bold text-n-text-display mb-2">
      {{ t('ONBOARDING.PROFILE_STEP.TITLE') }}
    </h1>
    <p class="text-sm text-n-text-body/60 mb-8">
      {{ t('ONBOARDING.PROFILE_STEP.SUBTITLE') }}
    </p>
    <div class="w-full max-w-xs flex flex-col gap-4">
      <NextInput
        v-model="displayName"
        :label="t('ONBOARDING.PROFILE_STEP.NAME_LABEL')"
        :placeholder="t('ONBOARDING.PROFILE_STEP.NAME_PLACEHOLDER')"
        :error="displayNameError"
        autofocus
        @enter="proceed"
        @blur="handleBlur"
      />

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
        :disabled="!canProceed"
        @click="proceed"
      />
    </div>
  </div>
</template>
