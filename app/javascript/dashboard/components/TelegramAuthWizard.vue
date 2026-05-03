<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import PhoneNumberInput from 'dashboard/components-next/phonenumberinput/PhoneNumberInput.vue';
import TelegramSessionsAPI from 'dashboard/api/telegramSessions';
import PageHeader from 'dashboard/routes/dashboard/settings/SettingsSubPageHeader.vue';

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

const stepTitle = computed(() => {
  const titles = {
    phone: t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.STEPS.PHONE_TITLE'),
    code: t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.STEPS.CODE_TITLE'),
    password: t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.STEPS.PASSWORD_TITLE'),
    ready: t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.STEPS.READY_TITLE'),
  };
  return titles[step.value];
});

const stepSubtitle = computed(() => {
  const subtitles = {
    phone: t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.STEPS.PHONE_SUBTITLE'),
    code: t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.STEPS.CODE_SUBTITLE'),
    password: t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.STEPS.PASSWORD_SUBTITLE'),
    ready: t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.STEPS.READY_SUBTITLE'),
  };
  return subtitles[step.value];
});

const statusColor = computed(() => {
  const colors = {
    authenticating: 'bg-n-amber-9',
    active: 'bg-n-teal-9',
    disconnected: 'bg-n-ruby-9',
  };
  return colors[connectionStatus.value] || 'bg-n-slate-8';
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
  lastError.value = '';

  try {
    const response = await callback();
    applyResponse(response.data);
  } catch (error) {
    const message =
      error?.response?.data?.error ||
      error?.response?.data?.message ||
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
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader :header-title="stepTitle" :header-content="stepSubtitle" />

    <!-- Status badge -->
    <div
      class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-n-alpha-2 mb-6"
    >
      <span class="w-2 h-2 rounded-full animate-pulse" :class="statusColor" />
      <span class="text-xs font-medium text-n-text-body">
        {{
          $t(
            `INBOX_MGMT.ADD.TELEGRAM_PERSONAL.STATUS.${connectionStatus.toUpperCase()}`
          )
        }}
      </span>
    </div>

    <!-- Error message -->
    <div
      v-if="lastError"
      class="flex items-start gap-2 px-4 py-3 rounded-xl bg-n-ruby-9/5 mb-6"
    >
      <Icon
        icon="i-lucide-alert-circle"
        class="size-4 text-n-ruby-9 mt-0.5 shrink-0"
      />
      <p class="text-sm text-n-ruby-11">
        {{ lastError }}
      </p>
    </div>

    <!-- Step: Phone -->
    <form
      v-if="step === 'phone'"
      class="flex flex-col gap-4"
      @submit.prevent="startAuthentication"
    >
      <NextInput
        v-model="form.name"
        :label="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.INBOX_NAME.LABEL')"
        :placeholder="
          $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.INBOX_NAME.PLACEHOLDER')
        "
      />

      <div>
        <label class="mb-1 block text-heading-3 text-n-text-display">
          {{ $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.PHONE_NUMBER.LABEL') }}
        </label>
        <PhoneNumberInput
          v-model="form.phoneNumber"
          :placeholder="
            $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.PHONE_NUMBER.PLACEHOLDER')
          "
        />
      </div>

      <div class="w-full mt-2">
        <NextButton
          type="submit"
          solid
          blue
          :is-loading="loading"
          icon="i-lucide-arrow-right"
          trailing-icon
          :label="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.SUBMIT_PHONE_BUTTON')"
        />
      </div>
    </form>

    <!-- Step: Code -->
    <form
      v-else-if="step === 'code'"
      class="flex flex-col gap-4"
      @submit.prevent="submitCode"
    >
      <NextInput
        v-model="form.code"
        :label="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.AUTH_CODE.LABEL')"
        :placeholder="
          $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.AUTH_CODE.PLACEHOLDER')
        "
        autofocus
      />

      <div class="flex gap-3 mt-2">
        <NextButton
          type="submit"
          solid
          blue
          :is-loading="loading"
          icon="i-lucide-check"
          trailing-icon
          :label="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.SUBMIT_CODE_BUTTON')"
        />
        <NextButton
          type="button"
          ghost
          slate
          icon="i-lucide-refresh-cw"
          :disabled="loading"
          :label="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.RECONNECT_BUTTON')"
          @click="reconnect"
        />
      </div>
    </form>

    <!-- Step: Password -->
    <form
      v-else-if="step === 'password'"
      class="flex flex-col gap-4"
      @submit.prevent="submitPassword"
    >
      <NextInput
        v-model="form.password"
        type="password"
        :label="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.PASSWORD.LABEL')"
        :placeholder="
          $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.PASSWORD.PLACEHOLDER')
        "
        autofocus
      />

      <div class="w-full mt-2">
        <NextButton
          type="submit"
          solid
          blue
          :is-loading="loading"
          icon="i-lucide-lock"
          trailing-icon
          :label="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.SUBMIT_PASSWORD_BUTTON')"
        />
      </div>
    </form>

    <!-- Step: Ready -->
    <div v-else class="flex flex-col">
      <p class="text-sm text-n-text-body mb-6">
        {{ $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.READY_MESSAGE') }}
      </p>
      <NextButton
        solid
        teal
        icon="i-lucide-arrow-right"
        trailing-icon
        :label="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.CONTINUE_BUTTON')"
        @click="goToAgentsStep"
      />
    </div>
  </div>
</template>
