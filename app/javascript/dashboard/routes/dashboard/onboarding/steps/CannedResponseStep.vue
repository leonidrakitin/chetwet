<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  isSaving: { type: Boolean, default: false },
  lastError: { type: String, default: null },
});

const emit = defineEmits(['next', 'retry']);
const { t } = useI18n();

const responses = ref([{ shortCode: '', content: '' }]);

function addRow() {
  if (responses.value.length < 3) {
    responses.value.push({ shortCode: '', content: '' });
  }
}

function removeRow(index) {
  responses.value.splice(index, 1);
  if (responses.value.length === 0) {
    responses.value.push({ shortCode: '', content: '' });
  }
}

function proceed() {
  const valid = responses.value.filter(
    r => r.shortCode.trim() && r.content.trim()
  );
  emit('next', { responses: valid });
}
</script>

<template>
  <div class="flex flex-col items-center text-center px-2">
    <div
      class="flex items-center justify-center w-16 h-16 rounded-2xl bg-n-brand/10 mb-6"
    >
      <Icon icon="i-lucide-zap" class="size-8 text-n-brand" />
    </div>
    <h1 class="text-2xl font-bold text-n-slate-12 mb-2">
      {{ t('ONBOARDING.CANNED_STEP.TITLE') }}
    </h1>
    <p class="text-sm text-n-slate-10 mb-6">
      {{ t('ONBOARDING.CANNED_STEP.SUBTITLE') }}
    </p>

    <div class="w-full max-w-sm flex flex-col gap-4">
      <div
        v-for="(response, index) in responses"
        :key="index"
        class="flex flex-col gap-2 rounded-lg border border-n-container p-3"
      >
        <div class="flex items-start gap-2">
          <div class="flex-1 flex flex-col gap-2">
            <NextInput
              v-model="response.shortCode"
              :label="t('ONBOARDING.CANNED_STEP.SHORT_CODE_LABEL')"
              :placeholder="t('ONBOARDING.CANNED_STEP.SHORT_CODE_PLACEHOLDER')"
            />
            <div class="text-left">
              <label class="text-sm font-medium text-n-slate-11 mb-1.5 block">
                {{ t('ONBOARDING.CANNED_STEP.CONTENT_LABEL') }}
              </label>
              <textarea
                v-model="response.content"
                :placeholder="t('ONBOARDING.CANNED_STEP.CONTENT_PLACEHOLDER')"
                rows="2"
                class="w-full rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-1 focus:ring-n-brand placeholder:text-n-slate-8 resize-none"
              />
            </div>
          </div>
          <button
            v-if="responses.length > 1"
            class="mt-6 text-n-slate-9 hover:text-n-slate-12 transition-colors"
            @click="removeRow(index)"
          >
            <Icon icon="i-lucide-x" class="size-4" />
          </button>
        </div>
      </div>

      <button
        v-if="responses.length < 3"
        class="flex items-center justify-center gap-1.5 text-sm text-n-brand hover:text-n-brand/80 transition-colors"
        @click="addRow"
      >
        <Icon icon="i-lucide-plus" class="size-4" />
        {{ t('ONBOARDING.CANNED_STEP.ADD_MORE') }}
      </button>

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
        class="mt-2 w-full"
        :label="isSaving ? t('ONBOARDING.SAVING') : t('ONBOARDING.NEXT')"
        :is-loading="isSaving"
        @click="proceed"
      />
    </div>
  </div>
</template>
