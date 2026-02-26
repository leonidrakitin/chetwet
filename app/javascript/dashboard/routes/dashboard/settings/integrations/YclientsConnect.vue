<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import integrationAPI from 'dashboard/api/integrations';
import NextButton from 'dashboard/components-next/button/Button.vue';

const route = useRoute();
const store = useStore();
const { t } = useI18n();

const selectedAccountId = ref(null);
const isSubmitting = ref(false);
const status = ref('idle');
const errorMessage = ref('');

const salonIds = computed(() => {
  const single = route.query.salon_id;
  const multiple = route.query.salon_ids;
  if (single !== undefined && single !== null) {
    const id = parseInt(Array.isArray(single) ? single[0] : single, 10);
    return Number.isNaN(id) ? [] : [id];
  }
  if (multiple !== undefined && multiple !== null) {
    const arr = Array.isArray(multiple) ? multiple : [multiple];
    return arr.map(s => parseInt(s, 10)).filter(n => !Number.isNaN(n));
  }
  return [];
});

const isLoggedIn = computed(() => store.getters.isLoggedIn);
const currentUser = computed(() => store.getters.getCurrentUser || {});
const accounts = computed(() => currentUser.value.accounts || []);

const hasValidSalonIds = computed(() => salonIds.value.length > 0);
const canConnect = computed(
  () =>
    isLoggedIn.value &&
    hasValidSalonIds.value &&
    selectedAccountId.value &&
    !isSubmitting.value
);

function closeFrame() {
  if (window.parent !== window) {
    window.parent.postMessage({ type: 'yclients-connect-close' }, '*');
  }
}

async function connect() {
  if (!canConnect.value) return;
  isSubmitting.value = true;
  errorMessage.value = '';
  status.value = 'idle';
  try {
    await integrationAPI.connectYclientsMarketplace(
      selectedAccountId.value,
      salonIds.value
    );
    status.value = 'success';
  } catch (err) {
    status.value = 'error';
    errorMessage.value =
      err.response?.data?.error ||
      err.message ||
      t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.ERROR');
  } finally {
    isSubmitting.value = false;
  }
}

onMounted(() => {
  store.dispatch('setUser');
  if (accounts.value.length === 1) {
    selectedAccountId.value = accounts.value[0].id;
  }
});
</script>

<template>
  <div class="flex flex-col min-h-[40vh] w-full max-w-lg mx-auto p-6 gap-4">
    <h1 class="text-lg font-semibold text-slate-12 dark:text-slate-2">
      {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.TITLE') }}
    </h1>

    <template v-if="!isLoggedIn">
      <p class="text-slate-11 dark:text-slate-4">
        {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.LOGIN_REQUIRED') }}
      </p>
      <a
        :href="`/app/login?return_url=${encodeURIComponent(route.fullPath)}`"
        class="text-woot-500 hover:underline"
      >
        {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.LOGIN_LINK') }}
      </a>
    </template>

    <template v-else-if="!hasValidSalonIds">
      <p class="text-slate-11 dark:text-slate-4">
        {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.MISSING_SALON_IDS') }}
      </p>
    </template>

    <template v-else>
      <template v-if="status === 'success'">
        <p class="text-slate-11 dark:text-slate-4">
          {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.SUCCESS') }}
        </p>
        <NextButton
          :label="t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.CLOSE')"
          @click="closeFrame"
        />
      </template>

      <template v-else>
        <p
          v-if="accounts.length > 1"
          class="text-sm text-slate-11 dark:text-slate-4"
        >
          {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.SELECT_ACCOUNT') }}
        </p>
        <select
          v-if="accounts.length > 1"
          v-model="selectedAccountId"
          class="rounded border border-slate-6 bg-slate-1 text-slate-12 dark:bg-slate-2 dark:text-slate-1 px-3 py-2"
        >
          <option v-for="acc in accounts" :key="acc.id" :value="acc.id">
            {{ acc.name }}
          </option>
        </select>
        <NextButton
          :label="t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.CONNECT')"
          :loading="isSubmitting"
          :disabled="!canConnect"
          @click="connect"
        />
        <p v-if="status === 'error'" class="text-ruby-11 text-sm">
          {{ errorMessage }}
        </p>
      </template>
    </template>
  </div>
</template>
