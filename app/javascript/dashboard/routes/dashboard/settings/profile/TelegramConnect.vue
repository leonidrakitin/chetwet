<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import authAPI from 'dashboard/api/auth';

const { t } = useI18n();
const store = useStore();

const telegramLink = ref('');
const isGenerating = ref(false);
const isDisconnecting = ref(false);

const currentUser = computed(() => store.getters.getCurrentUser);
const currentAccountId = computed(
  () => store.getters['auth/getCurrentAccountId']
);
const isConnected = computed(() => !!currentUser.value?.telegram_chat_id);

async function generateLink() {
  isGenerating.value = true;
  try {
    const { data } = await authAPI.generateTelegramLink(currentAccountId.value);
    telegramLink.value = data.url;
  } catch (error) {
    const msg =
      error?.response?.data?.error ||
      t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.LINK_ERROR');
    useAlert(msg);
  } finally {
    isGenerating.value = false;
  }
}

async function disconnect() {
  isDisconnecting.value = true;
  try {
    await authAPI.disconnectTelegram();
    await store.dispatch('validityCheck');
    telegramLink.value = '';
    useAlert(t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.DISCONNECTED'));
  } catch {
    useAlert(t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.DISCONNECT_ERROR'));
  } finally {
    isDisconnecting.value = false;
  }
}

function openLink() {
  window.open(telegramLink.value, '_blank');
}

// Re-check connection after generating link (user may have connected in Telegram)
let pollTimer = null;
watch(telegramLink, val => {
  if (val) {
    pollTimer = setInterval(async () => {
      await store.dispatch('validityCheck');
      if (currentUser.value?.telegram_chat_id) {
        clearInterval(pollTimer);
        telegramLink.value = '';
        useAlert(t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.UPDATE_SUCCESS'));
      }
    }, 5000);
  } else if (pollTimer) {
    clearInterval(pollTimer);
  }
});

onMounted(() => {
  // cleanup on unmount handled by vue reactivity
});
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- Connected state -->
    <div v-if="isConnected" class="flex flex-col gap-3">
      <p class="text-sm text-n-green-11">
        {{ t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.CONNECTED') }}
      </p>
      <NextButton
        type="button"
        variant="smooth"
        color-scheme="alert"
        :label="t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.DISCONNECT')"
        :is-loading="isDisconnecting"
        @click="disconnect"
      />
    </div>

    <!-- Link generated state -->
    <div v-else-if="telegramLink" class="flex flex-col gap-3">
      <p class="text-sm text-n-slate-11">
        {{ t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.LINK_HINT') }}
      </p>
      <NextButton
        type="button"
        icon="i-lucide-send"
        :label="t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.OPEN_TELEGRAM')"
        @click="openLink"
      />
      <p class="text-xs text-n-slate-10">
        {{ t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.WAITING') }}
      </p>
    </div>

    <!-- Default state -->
    <div v-else class="flex flex-col gap-3">
      <p class="text-sm text-n-slate-11">
        {{ t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.DESCRIPTION_NEW') }}
      </p>
      <NextButton
        type="button"
        icon="i-lucide-link"
        :label="t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.CONNECT')"
        :is-loading="isGenerating"
        @click="generateLink"
      />
    </div>
  </div>
</template>
