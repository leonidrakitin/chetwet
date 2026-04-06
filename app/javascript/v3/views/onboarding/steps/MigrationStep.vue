<script setup>
import { defineOptions } from 'vue';
import MigrationsWizard from 'dashboard/routes/dashboard/onboarding/MigrationsWizard.vue';

defineOptions({ inheritAttrs: false });
</script>

<template>
  <MigrationsWizard embedded />
</template>
