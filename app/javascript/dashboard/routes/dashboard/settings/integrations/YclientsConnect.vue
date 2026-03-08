<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import integrationAPI from 'dashboard/api/integrations';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { useBranding } from 'shared/composables/useBranding';

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();
const { replaceInstallationName } = useBranding();

const selectedAccountId = ref(null);
const isSubmitting = ref(false);
const status = ref('idle');
const errorMessage = ref('');

const view = ref('connect');
const userData = ref(null);
const editableUserData = ref(null);

function parseUserDataFromQuery() {
  const raw = route.query.user_data;
  if (!raw || typeof raw !== 'string') return null;
  try {
    const base64 = raw.replace(/-/g, '+').replace(/_/g, '/');
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
    const json = new TextDecoder().decode(bytes);
    const data = JSON.parse(json);
    return {
      email: data.email || '',
      phone: data.phone || '',
      name: data.name || '',
      id: data.id,
      salon_name: data.salon_name,
    };
  } catch {
    return null;
  }
}

function formatPhoneDisplay(phone) {
  if (!phone || typeof phone !== 'string') return '';
  const digits = phone.replace(/\D/g, '');
  if (digits.length >= 11 && digits.startsWith('7')) {
    return `+7 (${digits.slice(1, 4)}) ${digits.slice(4, 7)}-${digits.slice(7, 9)}-${digits.slice(9, 11)}`;
  }
  return phone;
}

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
const hasAccounts = computed(() => accounts.value.length > 0);

const hasValidSalonIds = computed(() => salonIds.value.length > 0);
const hasUserDataInUrl = computed(() => !!route.query.user_data);
const showWelcomeScreen = computed(
  () =>
    hasValidSalonIds.value &&
    hasUserDataInUrl.value &&
    ['welcome', 'edit', 'welcome-success'].includes(view.value)
);
const displayUserData = computed(
  () => editableUserData.value || userData.value
);

const canConnect = computed(
  () =>
    isLoggedIn.value &&
    hasValidSalonIds.value &&
    hasAccounts.value &&
    selectedAccountId.value &&
    !isSubmitting.value
);

function closeFrame() {
  if (window.parent !== window) {
    window.parent.postMessage({ type: 'yclients-connect-close' }, '*');
    return;
  }

  if (window.history.length > 1) {
    router.back();
    return;
  }

  window.location.href = '/app';
}

function goToLogin() {
  const returnUrl = encodeURIComponent(route.fullPath);
  window.location.href = `/app/login?return_url=${returnUrl}`;
}

function goToSignup() {
  const params = new URLSearchParams({ return_url: route.fullPath });
  if (displayUserData.value?.email)
    params.set('email', displayUserData.value.email);
  if (displayUserData.value?.phone)
    params.set('phone_number', displayUserData.value.phone);
  if (displayUserData.value?.name)
    params.set('name', displayUserData.value.name);
  window.location.href = `/app/auth/signup?${params.toString()}`;
}

function openEditData() {
  view.value = 'edit';
}

function saveEditData() {
  if (editableUserData.value) {
    editableUserData.value.phone = editableUserData.value.phone ?? '';
    editableUserData.value.email = editableUserData.value.email ?? '';
  }
  view.value = 'welcome';
}

function backFromEdit() {
  view.value = 'welcome';
  if (userData.value && editableUserData.value) {
    editableUserData.value.phone = userData.value.phone ?? '';
    editableUserData.value.email = userData.value.email ?? '';
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
  const parsed = parseUserDataFromQuery();
  if (hasValidSalonIds.value && route.query.user_data) {
    if (parsed) {
      userData.value = parsed;
      editableUserData.value = {
        email: parsed.email || '',
        phone: parsed.phone || '',
        name: parsed.name || '',
      };
    } else {
      userData.value = { email: '', phone: '', name: '' };
      editableUserData.value = { email: '', phone: '', name: '' };
    }
    view.value = 'welcome';
  }
  if (accounts.value.length === 1) {
    selectedAccountId.value = accounts.value[0].id;
  }
});

watch(
  () => route.query.user_data,
  () => {
    const parsed = parseUserDataFromQuery();
    if (parsed && (parsed.email || parsed.phone)) {
      userData.value = parsed;
      editableUserData.value = {
        email: parsed.email || '',
        phone: parsed.phone || '',
        name: parsed.name || '',
      };
      if (hasValidSalonIds.value) view.value = 'welcome';
    }
  }
);

async function connectFromWelcome() {
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
    view.value = 'welcome-success';
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
</script>

<template>
  <div class="flex flex-col min-h-[40vh] w-full max-w-lg mx-auto p-6 gap-4">
    <template v-if="showWelcomeScreen && view === 'welcome-success'">
      <div
        class="flex justify-center w-20 h-20 mx-auto rounded-full bg-green-100 dark:bg-green-900/30 items-center text-3xl"
      >
        <fluent-icon icon="checkmark" size="28" class="text-green-11" />
      </div>
      <h1 class="text-xl font-bold text-slate-12 dark:text-slate-2 text-center">
        {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.SUCCESS') }}
      </h1>
      <NextButton
        :label="t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.CLOSE')"
        @click="closeFrame"
      />
    </template>

    <template v-else-if="showWelcomeScreen && view === 'welcome'">
      <div
        class="flex justify-center w-20 h-20 mx-auto rounded-full bg-yellow-100 dark:bg-yellow-900/30 items-center text-3xl"
      >
        <fluent-icon icon="person" size="28" class="text-amber-11" />
      </div>
      <h1 class="text-xl font-bold text-slate-12 dark:text-slate-2 text-center">
        {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_TITLE') }}
      </h1>
      <p class="text-sm text-slate-11 dark:text-slate-4">
        {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_REGISTERED_AT') }}
      </p>
      <div class="flex flex-col gap-1 text-slate-12 dark:text-slate-2">
        <p v-if="displayUserData?.email" class="font-medium">
          {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_EMAIL') }}
          {{ displayUserData.email }}
        </p>
        <p v-if="displayUserData?.phone" class="font-medium">
          {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_PHONE') }}
          {{ formatPhoneDisplay(displayUserData.phone) }}
        </p>
        <p
          v-if="
            displayUserData && !displayUserData.email && !displayUserData.phone
          "
          class="text-slate-11 dark:text-slate-4 text-sm"
        >
          {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_REGISTERED_AT') }}
          {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.DATA_NOT_AVAILABLE') }}
        </p>
      </div>

      <template v-if="!isLoggedIn">
        <p class="text-sm text-slate-11 dark:text-slate-4">
          {{
            replaceInstallationName(
              t(
                'INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_CREATE_EXPLANATION'
              )
            )
          }}
        </p>
        <p class="text-xs text-slate-10 dark:text-slate-5">
          {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_CHANGE_HINT') }}
        </p>
        <p class="text-xs text-slate-10 dark:text-slate-5">
          {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_LOGIN_HINT') }}
        </p>
        <div class="flex flex-col gap-2 mt-2">
          <NextButton
            class="bg-yellow-400 hover:bg-yellow-500 border-yellow-500 text-slate-12 font-semibold"
            :label="t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_CREATE')"
            @click="goToSignup"
          />
          <NextButton
            faded
            slate
            :label="t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_CHANGE')"
            @click="openEditData"
          />
          <NextButton
            faded
            slate
            :label="t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_LOGIN')"
            @click="goToLogin"
          />
        </div>
      </template>

      <template v-else>
        <p v-if="!hasAccounts" class="text-sm text-slate-11 dark:text-slate-4">
          {{
            replaceInstallationName(
              t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.ZERO_ACCOUNTS')
            )
          }}
        </p>
        <p
          v-else-if="accounts.length > 1"
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
        <div class="flex flex-col gap-2 mt-2">
          <NextButton
            :label="t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.CONNECT')"
            :loading="isSubmitting"
            :disabled="!canConnect"
            @click="connectFromWelcome"
          />
          <p v-if="status === 'error'" class="text-ruby-11 text-sm">
            {{ errorMessage }}
          </p>
        </div>
      </template>
    </template>

    <template v-else-if="showWelcomeScreen && view === 'edit'">
      <h1 class="text-xl font-bold text-slate-12 dark:text-slate-2">
        {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.EDIT_TITLE') }}
      </h1>
      <p class="text-sm text-slate-11 dark:text-slate-4">
        {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.EDIT_INTRO') }}
      </p>
      <p class="text-sm text-slate-11 dark:text-slate-4">
        {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.EDIT_INSTRUCTION') }}
      </p>
      <Input
        v-if="editableUserData"
        v-model="editableUserData.phone"
        :label="t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.EDIT_PHONE')"
        type="tel"
        class="w-full"
      />
      <Input
        v-if="editableUserData"
        v-model="editableUserData.email"
        :label="t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.EDIT_EMAIL')"
        type="email"
        class="w-full"
      />
      <div class="flex flex-col gap-2 mt-2">
        <NextButton
          :label="t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.EDIT_SAVE')"
          @click="saveEditData"
        />
        <NextButton
          faded
          slate
          :label="t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.EDIT_BACK')"
          @click="backFromEdit"
        />
      </div>
    </template>

    <template v-else>
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
            v-if="!hasAccounts"
            class="text-sm text-slate-11 dark:text-slate-4"
          >
            {{
              replaceInstallationName(
                t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.ZERO_ACCOUNTS')
              )
            }}
          </p>
          <p
            v-else-if="accounts.length > 1"
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
    </template>
  </div>
</template>
