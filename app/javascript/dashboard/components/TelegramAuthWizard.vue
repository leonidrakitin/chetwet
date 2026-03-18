<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import PageHeader from 'dashboard/routes/dashboard/settings/SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TelegramSessionsAPI from 'dashboard/api/telegramSessions';

const { t } = useI18n();
const router = useRouter();

const loading = ref(false);
const telegramSessionId = ref(null);
const inboxId = ref(null);
const authState = ref('wait_phone_number');
const connectionStatus = ref('authenticating');
const lastError = ref('');

const form = reactive({
  name: '',
  phoneNumber: '',
  apiId: '',
  apiHash: '',
  code: '',
  password: '',
});

const step = computed(() => {
  if (connectionStatus.value === 'active' || authState.value === 'ready') {
    return 'ready';
  }

  if (authState.value === 'wait_password') {
    return 'password';
  }

  if (authState.value === 'wait_code') {
    return 'code';
  }

  return 'phone';
});

const statusKey = computed(() => {
  return `INBOX_MGMT.ADD.TELEGRAM_PERSONAL.STATUS.${connectionStatus.value.toUpperCase()}`;
});

const applyResponse = data => {
  telegramSessionId.value = data.id;
  inboxId.value = data.inbox_id;
  authState.value = data.auth_state;
  connectionStatus.value = data.status;
  lastError.value = data.last_error || '';
};

const withRequest = async callback => {
  loading.value = true;

  try {
    const response = await callback();
    applyResponse(response.data);
  } catch (error) {
    const message =
      error?.response?.data?.error ||
      error?.message ||
      t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.API.ERROR_MESSAGE');

    lastError.value = message;
    useAlert(message);
  } finally {
    loading.value = false;
  }
};

const startAuthentication = async () => {
  await withRequest(() =>
    TelegramSessionsAPI.create({
      name: form.name,
      phone_number: form.phoneNumber,
      api_id: form.apiId,
      api_hash: form.apiHash,
    })
  );
};

const submitCode = async () => {
  await withRequest(() =>
    TelegramSessionsAPI.submitCode(telegramSessionId.value, form.code)
  );
};

const submitPassword = async () => {
  await withRequest(() =>
    TelegramSessionsAPI.submitPassword(telegramSessionId.value, form.password)
  );
};

const reconnect = async () => {
  await withRequest(() =>
    TelegramSessionsAPI.reconnect(telegramSessionId.value)
  );
};

const goToAgentsStep = () => {
  router.replace({
    name: 'settings_inboxes_add_agents',
    params: {
      page: 'new',
      inbox_id: inboxId.value,
    },
  });
};
</script>

<template>
  <div class="h-full w-full col-span-6 p-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.DESC')"
    />

    <div class="max-w-2xl space-y-4">
      <div class="rounded-xl border border-n-slate-3 bg-n-background p-4">
        <p class="text-sm font-medium text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.CONNECTION_STATUS') }}
        </p>
        <p class="mt-1 text-sm text-n-slate-9">
          {{ $t(statusKey) }}
        </p>
        <p v-if="lastError" class="mt-2 text-sm text-ruby-9">
          {{ lastError }}
        </p>
      </div>

      <form
        v-if="step === 'phone'"
        class="space-y-4"
        @submit.prevent="startAuthentication"
      >
        <label class="block">
          <span class="mb-1 block text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.INBOX_NAME.LABEL') }}
          </span>
          <input
            v-model="form.name"
            type="text"
            class="w-full"
            :placeholder="
              $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.INBOX_NAME.PLACEHOLDER')
            "
          />
        </label>

        <label class="block">
          <span class="mb-1 block text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.PHONE_NUMBER.LABEL') }}
          </span>
          <input
            v-model="form.phoneNumber"
            type="text"
            class="w-full"
            :placeholder="
              $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.PHONE_NUMBER.PLACEHOLDER')
            "
          />
        </label>

        <label class="block">
          <span class="mb-1 block text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.API_ID.LABEL') }}
          </span>
          <input
            v-model="form.apiId"
            type="text"
            class="w-full"
            :placeholder="
              $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.API_ID.PLACEHOLDER')
            "
          />
        </label>

        <label class="block">
          <span class="mb-1 block text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.API_HASH.LABEL') }}
          </span>
          <input
            v-model="form.apiHash"
            type="password"
            class="w-full"
            :placeholder="
              $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.API_HASH.PLACEHOLDER')
            "
          />
        </label>

        <NextButton
          type="submit"
          solid
          blue
          :is-loading="loading"
          :label="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.SUBMIT_PHONE_BUTTON')"
        />
      </form>

      <form
        v-else-if="step === 'code'"
        class="space-y-4"
        @submit.prevent="submitCode"
      >
        <label class="block">
          <span class="mb-1 block text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.AUTH_CODE.LABEL') }}
          </span>
          <input
            v-model="form.code"
            type="text"
            class="w-full"
            :placeholder="
              $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.AUTH_CODE.PLACEHOLDER')
            "
          />
        </label>

        <div class="flex gap-3">
          <NextButton
            type="submit"
            solid
            blue
            :is-loading="loading"
            :label="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.SUBMIT_CODE_BUTTON')"
          />
          <NextButton
            type="button"
            outline
            slate
            :is-loading="loading"
            :label="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.RECONNECT_BUTTON')"
            @click="reconnect"
          />
        </div>
      </form>

      <form
        v-else-if="step === 'password'"
        class="space-y-4"
        @submit.prevent="submitPassword"
      >
        <label class="block">
          <span class="mb-1 block text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.PASSWORD.LABEL') }}
          </span>
          <input
            v-model="form.password"
            type="password"
            class="w-full"
            :placeholder="
              $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.PASSWORD.PLACEHOLDER')
            "
          />
        </label>

        <NextButton
          type="submit"
          solid
          blue
          :is-loading="loading"
          :label="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.SUBMIT_PASSWORD_BUTTON')"
        />
      </form>

      <div v-else class="rounded-xl border border-n-slate-3 bg-n-alpha-2 p-5">
        <p class="text-sm text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.READY_MESSAGE') }}
        </p>
        <div class="mt-4">
          <NextButton
            solid
            teal
            :label="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.CONTINUE_BUTTON')"
            @click="goToAgentsStep"
          />
        </div>
      </div>
    </div>
  </div>
</template>
