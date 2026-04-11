<script setup>
import MigrationsWizard from '../MigrationsWizard.vue';

const emit = defineEmits(['finish']);
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
        {{ $t('CAPTAIN.MIGRATIONS.HEADER') }}
      </h1>
      <p class="text-sm text-n-slate-10 max-w-md">
        {{ $t('CAPTAIN.MIGRATIONS.DESCRIPTION') }}
      </p>
    </div>

    <div class="mt-2">
      <MigrationsWizard embedded />
    </div>

    <div class="flex justify-end mt-4">
      <button
        class="px-4 py-2 text-sm font-medium text-white bg-n-brand rounded-lg hover:bg-n-brand/90 transition-colors"
        @click="emit('finish')"
      >
        {{ $t('ONBOARDING.COMPLETE_STEP.GO_TO_DASHBOARD') }}
      </button>
    </div>
  </div>
</template>
