<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['next']);
const { t } = useI18n();
const store = useStore();

const displayName = ref('');

onMounted(() => {
  const user = store.getters['auth/getCurrentUser'];
  displayName.value = user?.display_name || user?.name || '';
});

function proceed() {
  if (!displayName.value.trim()) return;
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
    <h1 class="text-2xl font-bold text-n-slate-12 mb-2">
      {{ t('ONBOARDING.PROFILE_STEP.TITLE') }}
    </h1>
    <p class="text-sm text-n-slate-10 mb-8">
      {{ t('ONBOARDING.PROFILE_STEP.SUBTITLE') }}
    </p>
    <div class="w-full max-w-xs flex flex-col gap-4">
      <NextInput
        v-model="displayName"
        :label="t('ONBOARDING.PROFILE_STEP.NAME_LABEL')"
        :placeholder="t('ONBOARDING.PROFILE_STEP.NAME_PLACEHOLDER')"
        autofocus
        @enter="proceed"
      />
      <NextButton
        class="mt-6 w-full"
        :label="isSaving ? t('ONBOARDING.SAVING') : t('ONBOARDING.NEXT')"
        :is-loading="isSaving"
        :disabled="!displayName.trim()"
        @click="proceed"
      />
    </div>
  </div>
</template>
