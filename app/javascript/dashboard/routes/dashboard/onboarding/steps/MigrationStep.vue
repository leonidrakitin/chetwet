<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import MigrationsWizard from '../MigrationsWizard.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

defineProps({
  lastError: { type: String, default: null },
});

const emit = defineEmits(['finish', 'retry']);
const { t } = useI18n();

const showMigration = ref(false);

function handleSkip() {
  emit('finish');
}

function handleMigrationComplete() {
  emit('finish');
}
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex flex-col items-center text-center">
      <div
        class="flex items-center justify-center w-14 h-14 rounded-2xl bg-n-brand/10 mb-4"
      >
        <div class="i-lucide-database size-7 text-n-brand" />
      </div>
      <h1 class="text-xl font-bold text-n-slate-12 mb-1">
        {{ t('CAPTAIN.MIGRATIONS.HEADER') }}
      </h1>
      <p class="text-sm text-n-slate-10 max-w-md">
        {{ t('ONBOARDING.MIGRATION_STEP.SUBTITLE') }}
      </p>
    </div>

    <div v-if="!showMigration" class="flex flex-col gap-3">
      <p class="text-xs text-n-slate-9 text-center">
        {{ t('ONBOARDING.MIGRATION_STEP.DESCRIPTION') }}
      </p>
      <div class="flex gap-2 mt-2">
        <NextButton
          variant="outline"
          class="flex-1"
          :label="t('ONBOARDING.MIGRATION_STEP.SKIP_MIGRATION')"
          @click="handleSkip"
        />
        <NextButton
          class="flex-1"
          :label="t('ONBOARDING.MIGRATION_STEP.START_MIGRATION')"
          icon="i-lucide-arrow-right"
          @click="showMigration = true"
        />
      </div>
    </div>

    <div v-else class="mt-2">
      <MigrationsWizard embedded @complete="handleMigrationComplete" />
      <div class="flex justify-end mt-4">
        <NextButton
          :label="t('ONBOARDING.COMPLETE_STEP.GO_TO_DASHBOARD')"
          @click="handleSkip"
        />
      </div>
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
  </div>
</template>
