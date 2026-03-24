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

const stepIndex = computed(() => {
  const steps = ['phone', 'code', 'password', 'ready'];
  return steps.indexOf(step.value);
});

const totalSteps = 4;

const stepIcon = computed(() => {
  const icons = {
    phone: 'i-lucide-smartphone',
    code: 'i-lucide-shield-check',
    password: 'i-lucide-lock',
    ready: 'i-lucide-check-circle',
  };
  return icons[step.value];
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
  <div
    class="flex items-center justify-center w-full min-h-full bg-gradient-to-br from-n-brand/5 via-n-background to-n-brand/10 dark:from-n-background dark:via-n-solid-1 dark:to-n-background p-6"
  >
    <div
      class="w-full max-w-md mx-auto flex flex-col bg-white dark:bg-n-solid-2 rounded-2xl shadow-lg ring-1 ring-n-container/50 dark:ring-n-container overflow-hidden"
    >
      <!-- Content -->
      <div class="px-8 py-8 flex flex-col items-center text-center">
        <!-- Step icon -->
        <div
          class="flex items-center justify-center w-16 h-16 rounded-2xl mb-6 transition-all duration-300"
          :class="step === 'ready' ? 'bg-n-teal-9/10' : 'bg-n-brand/10'"
        >
          <Icon
            :icon="stepIcon"
            class="size-8 transition-colors duration-300"
            :class="step === 'ready' ? 'text-n-teal-9' : 'text-n-brand'"
          />
        </div>

        <!-- Title & subtitle -->
        <h1 class="text-2xl font-bold text-n-slate-12 mb-2">
          {{ stepTitle }}
        </h1>
        <p class="text-sm text-n-slate-10 mb-6">
          {{ stepSubtitle }}
        </p>

        <!-- Status badge -->
        <div
          class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-n-alpha-2 mb-6"
        >
          <span
            class="w-2 h-2 rounded-full animate-pulse"
            :class="statusColor"
          />
          <span class="text-xs font-medium text-n-slate-11">
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
          class="w-full flex items-start gap-2 px-4 py-3 rounded-xl bg-n-ruby-9/5 mb-6"
        >
          <Icon
            icon="i-lucide-alert-circle"
            class="size-4 text-n-ruby-9 mt-0.5 shrink-0"
          />
          <p class="text-sm text-n-ruby-11 text-left">
            {{ lastError }}
          </p>
        </div>

        <!-- Step: Phone -->
        <form
          v-if="step === 'phone'"
          class="w-full flex flex-col gap-4 text-left"
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
            <label class="mb-1 block text-heading-3 text-n-slate-12">
              {{ $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.PHONE_NUMBER.LABEL') }}
            </label>
            <PhoneNumberInput
              v-model="form.phoneNumber"
              :placeholder="
                $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.PHONE_NUMBER.PLACEHOLDER')
              "
            />
          </div>

          <NextButton
            type="submit"
            class="w-full mt-2"
            solid
            blue
            :is-loading="loading"
            icon="i-lucide-arrow-right"
            trailing-icon
            :label="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.SUBMIT_PHONE_BUTTON')"
          />
        </form>

        <!-- Step: Code -->
        <form
          v-else-if="step === 'code'"
          class="w-full flex flex-col gap-4 text-left"
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
              class="flex-1"
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
          class="w-full flex flex-col gap-4 text-left"
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

          <NextButton
            type="submit"
            class="w-full mt-2"
            solid
            blue
            :is-loading="loading"
            icon="i-lucide-lock"
            trailing-icon
            :label="
              $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.SUBMIT_PASSWORD_BUTTON')
            "
          />
        </form>

        <!-- Step: Ready -->
        <div v-else class="w-full flex flex-col items-center">
          <p class="text-sm text-n-slate-11 mb-6">
            {{ $t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.READY_MESSAGE') }}
          </p>
          <NextButton
            class="w-full"
            solid
            teal
            icon="i-lucide-arrow-right"
            trailing-icon
            :label="$t('INBOX_MGMT.ADD.TELEGRAM_PERSONAL.CONTINUE_BUTTON')"
            @click="goToAgentsStep"
          />
        </div>
      </div>

      <!-- Footer: progress dots -->
      <div class="flex items-center justify-center gap-2 pb-6">
        <span
          v-for="i in totalSteps"
          :key="i"
          class="h-2 rounded-full transition-all duration-300"
          :class="
            i - 1 === stepIndex
              ? 'w-6 bg-n-brand'
              : i - 1 < stepIndex
                ? 'w-2 bg-n-brand/40'
                : 'w-2 bg-n-slate-4'
          "
        />
      </div>
    </div>
  </div>
</template>
