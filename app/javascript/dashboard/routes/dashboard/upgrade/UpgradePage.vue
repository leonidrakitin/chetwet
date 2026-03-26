<script setup>
import { computed, defineExpose } from 'vue';

const shouldShowUpgradePage = computed(() => false);
defineExpose({ shouldShowUpgradePage });
</script>

<template>
  <div v-if="shouldShowUpgradePage" />
  <div v-else />
</template>
