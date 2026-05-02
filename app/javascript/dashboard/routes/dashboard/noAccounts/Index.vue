<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Auth from 'dashboard/api/auth';

const { t } = useI18n();
const isOnChatwootCloud = useMapGetter('globalConfig/isOnChatwootCloud');

const message = computed(() => {
  if (isOnChatwootCloud.value) {
    return t('APP_GLOBAL.NO_ACCOUNTS.MESSAGE_CLOUD');
  }
  return t('APP_GLOBAL.NO_ACCOUNTS.MESSAGE_SELF_HOSTED');
});

const handleLogout = () => {
  Auth.logout();
};
</script>

<template>
  <div class="flex flex-1 items-center justify-center w-full h-full m-2.5">
    <div
      class="bg-n-glass-strong backdrop-blur-glass-card backdrop-saturate-glass border border-n-border-glass rounded-card-lg shadow-glass-deep px-10 py-12 max-w-xl w-full flex flex-col items-center gap-6"
    >
      <EmptyState
        :title="$t('APP_GLOBAL.NO_ACCOUNTS.TITLE')"
        :message="message"
      />
      <NextButton
        variant="smooth"
        color-scheme="secondary"
        :label="$t('APP_GLOBAL.NO_ACCOUNTS.LOGOUT')"
        @click="handleLogout"
      />
    </div>
  </div>
</template>
