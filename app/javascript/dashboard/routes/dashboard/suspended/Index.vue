<script setup>
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import { onMounted } from 'vue';

const toggleSupportWidgetVisibility = () => {
  if (window.$chatwoot) {
    window.$chatwoot.toggleBubbleVisibility('show');
  }
};

const setupListenerForWidgetEvent = () => {
  window.addEventListener('chatwoot:on-message', () => {
    toggleSupportWidgetVisibility();
  });
};

onMounted(() => {
  toggleSupportWidgetVisibility();
  setupListenerForWidgetEvent();
});
</script>

<template>
  <div class="flex justify-center items-center w-full h-full m-2.5">
    <div
      class="bg-n-glass-strong backdrop-blur-glass-card backdrop-saturate-glass border border-n-border-glass rounded-card-lg shadow-glass-deep px-10 py-12 max-w-xl w-full"
    >
      <EmptyState
        :title="$t('APP_GLOBAL.ACCOUNT_SUSPENDED.TITLE')"
        :message="$t('APP_GLOBAL.ACCOUNT_SUSPENDED.MESSAGE')"
      />
    </div>
  </div>
</template>
