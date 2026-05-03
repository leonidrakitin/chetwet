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

/** Public URL for Yclients integration images (avoids Vite resolving as module). */
function yclientsImage(name) {
  return `/dashboard/images/integrations/${name}`;
}

const selectedAccountId = ref(null);
const isSubmitting = ref(false);
const isCheckingConnectionStatus = ref(false);
const status = ref('idle');
const errorMessage = ref('');
const connectedSalonIds = ref([]);

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
const isAlreadyConnected = computed(
  () =>
    hasValidSalonIds.value &&
    salonIds.value.every(id => connectedSalonIds.value.includes(id))
);
const connectButtonLabel = computed(() => {
  if (isCheckingConnectionStatus.value) {
    return t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.CHECKING_STATUS');
  }

  if (isAlreadyConnected.value || status.value === 'already_connected') {
    return t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.ALREADY_CONNECTED');
  }

  return t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.CONNECT');
});

const canConnect = computed(
  () =>
    isLoggedIn.value &&
    hasValidSalonIds.value &&
    hasAccounts.value &&
    selectedAccountId.value &&
    !isSubmitting.value &&
    !isCheckingConnectionStatus.value &&
    !isAlreadyConnected.value
);

async function refreshConnectionStatus() {
  if (
    !isLoggedIn.value ||
    !hasValidSalonIds.value ||
    !selectedAccountId.value
  ) {
    connectedSalonIds.value = [];
    return;
  }

  isCheckingConnectionStatus.value = true;
  try {
    const response = await integrationAPI.getYclientsMarketplaceStatus(
      selectedAccountId.value,
      salonIds.value
    );
    connectedSalonIds.value = response.data.connected_salon_ids || [];
    if (response.data.status === 'already_connected') {
      status.value = 'already_connected';
    } else if (status.value === 'already_connected') {
      status.value = 'idle';
    }
  } catch {
    connectedSalonIds.value = [];
  } finally {
    isCheckingConnectionStatus.value = false;
  }
}

function applyConnectResponse(response, successView = false) {
  connectedSalonIds.value = response.connected_salon_ids || [];

  if (response.status === 'already_connected') {
    status.value = 'already_connected';
    return;
  }

  status.value = 'success';
  if (successView) {
    view.value = 'welcome-success';
  }
}

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
    const { data } = await integrationAPI.connectYclientsMarketplace(
      selectedAccountId.value,
      salonIds.value
    );
    applyConnectResponse(data);
  } catch (err) {
    connectedSalonIds.value =
      err.response?.data?.connected_salon_ids || connectedSalonIds.value;
    status.value = 'error';
    errorMessage.value =
      err.response?.data?.error ||
      err.message ||
      t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.ERROR');
  } finally {
    isSubmitting.value = false;
  }
}

async function connectFromWelcome() {
  if (!canConnect.value) return;
  isSubmitting.value = true;
  errorMessage.value = '';
  status.value = 'idle';
  try {
    const { data } = await integrationAPI.connectYclientsMarketplace(
      selectedAccountId.value,
      salonIds.value
    );
    applyConnectResponse(data, true);
  } catch (err) {
    connectedSalonIds.value =
      err.response?.data?.connected_salon_ids || connectedSalonIds.value;
    status.value = 'error';
    errorMessage.value =
      err.response?.data?.error ||
      err.message ||
      t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.ERROR');
  } finally {
    isSubmitting.value = false;
  }
}

onMounted(async () => {
  await store.dispatch('setUser');
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
  await refreshConnectionStatus();
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

watch(
  [
    () => isLoggedIn.value,
    () => selectedAccountId.value,
    () => salonIds.value.join(','),
  ],
  () => {
    refreshConnectionStatus();
  }
);
</script>

<template>
  <div
    class="flex min-h-screen w-full items-start justify-center bg-n-background p-4 sm:p-8"
  >
    <div class="w-full max-w-md sm:max-w-lg">
      <!-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -->
      <!-- SUCCESS                                     -->
      <!-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -->
      <template v-if="showWelcomeScreen && view === 'welcome-success'">
        <div
          class="flex flex-col items-center gap-6 rounded-[1.75rem] border border-n-border-glass bg-n-glass-strong backdrop-blur-glass-card backdrop-saturate-glass p-8 shadow-glass-deep"
        >
          <!-- success icon + logo -->
          <div class="flex flex-col items-center gap-3">
            <div
              class="flex h-16 w-16 items-center justify-center rounded-full bg-n-blue-3"
            >
              <fluent-icon
                icon="checkmark-circle"
                size="32"
                class="text-n-blue-11"
              />
            </div>
            <img
              :src="yclientsImage('yclients-full.png')"
              alt="YCLIENTS"
              class="h-6 dark:invert"
            />
          </div>

          <div class="text-center">
            <h1 class="text-lg font-semibold text-n-text-display">
              {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.SUCCESS_TITLE') }}
            </h1>
            <p class="mt-1.5 text-sm leading-relaxed text-n-text-body">
              {{
                t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.SUCCESS_DESCRIPTION')
              }}
            </p>
          </div>

          <!-- feature pills -->
          <div class="flex flex-wrap justify-center gap-2">
            <span
              class="inline-flex items-center gap-1.5 rounded-full bg-n-blue-3 px-3 py-1 text-xs font-medium text-n-blue-11"
            >
              <fluent-icon icon="people" size="12" />
              {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.FEATURE_CONTACTS') }}
            </span>
            <span
              class="inline-flex items-center gap-1.5 rounded-full bg-n-blue-3 px-3 py-1 text-xs font-medium text-n-blue-11"
            >
              <fluent-icon icon="calendar" size="12" />
              {{
                t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.FEATURE_APPOINTMENTS')
              }}
            </span>
            <span
              class="inline-flex items-center gap-1.5 rounded-full bg-n-blue-3 px-3 py-1 text-xs font-medium text-n-blue-11"
            >
              <fluent-icon icon="bot" size="12" />
              {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.FEATURE_AI') }}
            </span>
          </div>

          <NextButton
            class="w-full"
            :label="t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.SUCCESS_CLOSE')"
            @click="closeFrame"
          />
        </div>
      </template>

      <!-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -->
      <!-- WELCOME                                     -->
      <!-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -->
      <template v-else-if="showWelcomeScreen && view === 'welcome'">
        <div
          class="flex flex-col gap-6 rounded-[1.75rem] border border-n-border-glass bg-n-glass-strong backdrop-blur-glass-card backdrop-saturate-glass p-8 shadow-glass-deep"
        >
          <!-- header -->
          <div class="flex flex-col items-center gap-3 text-center">
            <img
              :src="yclientsImage('yclients-full.png')"
              alt="YCLIENTS"
              class="h-8 dark:invert"
            />
            <h1 class="text-lg font-semibold text-n-text-display">
              {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_TITLE') }}
            </h1>
            <p class="text-sm leading-relaxed text-n-text-body">
              {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_SUBTITLE') }}
            </p>
          </div>

          <!-- salon info card -->
          <div
            class="rounded-2xl border border-n-border-glass-soft bg-n-glass-soft p-5"
          >
            <p
              class="mb-3 text-xs font-medium uppercase tracking-wide text-n-text-body/60"
            >
              {{
                t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_REGISTERED_AT')
              }}
            </p>

            <div class="flex flex-col gap-3">
              <!-- salon name -->
              <div
                v-if="displayUserData?.salon_name"
                class="flex items-center gap-3"
              >
                <div
                  class="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-n-blue-3 text-n-blue-11"
                >
                  <fluent-icon
                    icon="building"
                    size="14"
                    class="text-n-blue-11"
                  />
                </div>
                <div class="min-w-0">
                  <p class="text-xs text-n-text-body/60">
                    {{
                      t(
                        'INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_SALON_NAME'
                      )
                    }}
                  </p>
                  <p class="truncate text-sm font-medium text-n-text-display">
                    {{ displayUserData.salon_name }}
                  </p>
                </div>
              </div>

              <!-- email -->
              <div
                v-if="displayUserData?.email"
                class="flex items-center gap-3"
              >
                <div
                  class="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-n-blue-3 text-n-blue-11"
                >
                  <fluent-icon icon="mail" size="14" class="text-n-blue-11" />
                </div>
                <div class="min-w-0">
                  <p class="text-xs text-n-text-body/60">
                    {{
                      t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_EMAIL')
                    }}
                  </p>
                  <p class="truncate text-sm font-medium text-n-text-display">
                    {{ displayUserData.email }}
                  </p>
                </div>
              </div>

              <!-- phone -->
              <div
                v-if="displayUserData?.phone"
                class="flex items-center gap-3"
              >
                <div
                  class="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-n-blue-3 text-n-blue-11"
                >
                  <fluent-icon icon="call" size="14" class="text-n-blue-11" />
                </div>
                <div class="min-w-0">
                  <p class="text-xs text-n-text-body/60">
                    {{
                      t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_PHONE')
                    }}
                  </p>
                  <p class="truncate text-sm font-medium text-n-text-display">
                    {{ formatPhoneDisplay(displayUserData.phone) }}
                  </p>
                </div>
              </div>

              <!-- fallback when no data -->
              <p
                v-if="
                  displayUserData &&
                  !displayUserData.email &&
                  !displayUserData.phone &&
                  !displayUserData.salon_name
                "
                class="text-sm text-n-text-body/60"
              >
                {{
                  t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.DATA_NOT_AVAILABLE')
                }}
              </p>
            </div>
          </div>

          <!-- ── NOT LOGGED IN ── -->
          <template v-if="!isLoggedIn">
            <div class="flex flex-col gap-3">
              <p class="text-sm leading-relaxed text-n-text-body">
                {{
                  replaceInstallationName(
                    t(
                      'INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_CREATE_EXPLANATION'
                    )
                  )
                }}
              </p>
              <NextButton
                class="w-full"
                :label="
                  t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_CREATE')
                "
                @click="goToSignup"
              />
            </div>

            <!-- divider -->
            <div class="flex items-center gap-3">
              <div class="h-px flex-1 bg-n-container" />
              <span class="text-xs text-n-text-body/60">
                {{
                  t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_OR_DIVIDER')
                }}
              </span>
              <div class="h-px flex-1 bg-n-container" />
            </div>

            <div class="flex flex-col gap-2">
              <NextButton
                faded
                slate
                class="w-full"
                :label="
                  t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_LOGIN')
                "
                @click="goToLogin"
              />
              <NextButton
                faded
                slate
                class="w-full"
                :label="
                  t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_CHANGE')
                "
                @click="openEditData"
              />
            </div>

            <p class="text-center text-xs leading-relaxed text-n-text-body/60">
              {{
                t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.WELCOME_CHANGE_HINT')
              }}
            </p>
          </template>

          <!-- ── LOGGED IN ── -->
          <template v-else>
            <!-- zero accounts warning -->
            <div
              v-if="!hasAccounts"
              class="flex items-start gap-2.5 rounded-lg bg-n-amber-3 p-3"
            >
              <fluent-icon
                icon="warning"
                size="16"
                class="mt-0.5 shrink-0 text-n-amber-11"
              />
              <p class="text-sm text-n-amber-11">
                {{
                  replaceInstallationName(
                    t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.ZERO_ACCOUNTS')
                  )
                }}
              </p>
            </div>

            <template v-else>
              <!-- account picker -->
              <div v-if="accounts.length > 1" class="flex flex-col gap-1.5">
                <label class="text-sm font-medium text-n-text-display">
                  {{
                    t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.SELECT_ACCOUNT')
                  }}
                </label>
                <select
                  v-model="selectedAccountId"
                  class="rounded-xl border border-n-border-glass-soft bg-n-glass-soft px-4 py-3 text-sm text-n-text-display outline-none transition-colors focus:border-n-brand focus:ring-1 focus:ring-n-brand"
                >
                  <option v-for="acc in accounts" :key="acc.id" :value="acc.id">
                    {{ acc.name }}
                  </option>
                </select>
              </div>

              <NextButton
                class="w-full"
                :label="connectButtonLabel"
                :loading="isSubmitting || isCheckingConnectionStatus"
                :disabled="!canConnect"
                @click="connectFromWelcome"
              />

              <div
                v-if="isAlreadyConnected || status === 'already_connected'"
                class="flex items-start gap-2.5 rounded-xl border border-n-blue-7/30 bg-n-blue-3 p-3.5"
              >
                <fluent-icon
                  icon="checkmark-circle"
                  size="16"
                  class="mt-0.5 shrink-0 text-n-blue-11"
                />
                <p class="text-sm text-n-blue-11">
                  {{
                    t(
                      'INTEGRATION_SETTINGS.YCLIENTS_CONNECT.ALREADY_CONNECTED_HINT'
                    )
                  }}
                </p>
              </div>
            </template>

            <!-- error -->
            <div
              v-if="status === 'error'"
              class="flex items-start gap-2.5 rounded-lg bg-n-ruby-3 p-3"
            >
              <fluent-icon
                icon="warning"
                size="16"
                class="mt-0.5 shrink-0 text-n-ruby-11"
              />
              <p class="text-sm text-n-ruby-11">{{ errorMessage }}</p>
            </div>
          </template>
        </div>

        <!-- feature bar below the card -->
        <div class="mt-4 flex flex-col items-center gap-3">
          <div class="flex flex-wrap justify-center gap-4">
            <span class="flex items-center gap-1.5 text-xs text-n-text-body/60">
              <fluent-icon icon="people" size="12" />
              {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.FEATURE_CONTACTS') }}
            </span>
            <span class="flex items-center gap-1.5 text-xs text-n-text-body/60">
              <fluent-icon icon="calendar" size="12" />
              {{
                t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.FEATURE_APPOINTMENTS')
              }}
            </span>
            <span class="flex items-center gap-1.5 text-xs text-n-text-body/60">
              <fluent-icon icon="bot" size="12" />
              {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.FEATURE_AI') }}
            </span>
          </div>
          <span class="flex items-center gap-1.5 text-xs text-n-text-body/60">
            {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.POWERED_BY') }}
            <img
              :src="yclientsImage('yclients.png')"
              alt="YCLIENTS"
              class="h-4 w-4 block dark:hidden"
            />
            <img
              :src="yclientsImage('yclients-dark.png')"
              alt="YCLIENTS"
              class="h-4 w-4 hidden dark:block"
            />
          </span>
        </div>
      </template>

      <!-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -->
      <!-- EDIT DATA                                   -->
      <!-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -->
      <template v-else-if="showWelcomeScreen && view === 'edit'">
        <div
          class="flex flex-col gap-5 rounded-[1.75rem] border border-n-border-glass bg-n-glass-strong backdrop-blur-glass-card backdrop-saturate-glass p-8 shadow-glass-deep"
        >
          <div class="flex flex-col items-center gap-2 text-center">
            <div
              class="flex h-14 w-14 items-center justify-center rounded-2xl bg-n-blue-3"
            >
              <fluent-icon icon="edit" size="24" class="text-n-blue-11" />
            </div>
            <h1 class="text-lg font-semibold text-n-text-display">
              {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.EDIT_TITLE') }}
            </h1>
            <p class="text-sm leading-relaxed text-n-text-body">
              {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.EDIT_INTRO') }}
            </p>
          </div>

          <div class="flex flex-col gap-4">
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
          </div>

          <div class="flex flex-col gap-2">
            <NextButton
              class="w-full"
              :label="t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.EDIT_SAVE')"
              @click="saveEditData"
            />
            <NextButton
              faded
              slate
              class="w-full"
              :label="t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.EDIT_BACK')"
              @click="backFromEdit"
            />
          </div>
        </div>
      </template>

      <!-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -->
      <!-- FALLBACK (direct URL, no user_data)         -->
      <!-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -->
      <template v-else>
        <div
          class="flex flex-col gap-6 rounded-[1.75rem] border border-n-border-glass bg-n-glass-strong backdrop-blur-glass-card backdrop-saturate-glass p-8 shadow-glass-deep"
        >
          <!-- header -->
          <div class="flex flex-col items-center gap-3 text-center">
            <img
              :src="yclientsImage('yclients-full.png')"
              alt="YCLIENTS"
              class="h-8 dark:invert"
            />
            <h1 class="text-lg font-semibold text-n-text-display">
              {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.TITLE') }}
            </h1>
            <p class="text-sm leading-relaxed text-n-text-body">
              {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.SUBTITLE') }}
            </p>
          </div>

          <!-- not logged in -->
          <template v-if="!isLoggedIn">
            <div
              class="flex flex-col items-center gap-3 rounded-2xl border border-n-border-glass-soft bg-n-glass-soft p-5 text-center"
            >
              <fluent-icon
                icon="person-lock"
                size="24"
                class="text-n-text-body/60"
              />
              <p class="text-sm text-n-text-body">
                {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.LOGIN_REQUIRED') }}
              </p>
              <a
                :href="`/app/login?return_url=${encodeURIComponent(route.fullPath)}`"
                class="text-sm font-medium text-n-brand hover:underline"
              >
                {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.LOGIN_LINK') }}
              </a>
            </div>
          </template>

          <!-- no salon ids -->
          <template v-else-if="!hasValidSalonIds">
            <div
              class="flex flex-col items-center gap-3 rounded-2xl bg-n-amber-3 p-5 text-center"
            >
              <fluent-icon icon="warning" size="24" class="text-n-amber-11" />
              <p class="text-sm font-medium text-n-amber-11">
                {{
                  t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.MISSING_SALON_IDS')
                }}
              </p>
              <p class="text-xs text-n-amber-10">
                {{
                  t(
                    'INTEGRATION_SETTINGS.YCLIENTS_CONNECT.MISSING_SALON_IDS_HINT'
                  )
                }}
              </p>
            </div>
          </template>

          <!-- logged in + has salon ids -->
          <template v-else>
            <!-- success -->
            <template v-if="status === 'success'">
              <div
                class="flex flex-col items-center gap-3 rounded-2xl border border-n-blue-7/30 bg-n-blue-3 p-5 text-center"
              >
                <fluent-icon
                  icon="checkmark-circle"
                  size="28"
                  class="text-n-blue-11"
                />
                <p class="text-sm font-medium text-n-blue-11">
                  {{ t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.SUCCESS_TITLE') }}
                </p>
              </div>
              <NextButton
                class="w-full"
                :label="t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.CLOSE')"
                @click="closeFrame"
              />
            </template>

            <!-- connect form -->
            <template v-else>
              <div
                v-if="!hasAccounts"
                class="flex items-start gap-2.5 rounded-lg bg-n-amber-3 p-3"
              >
                <fluent-icon
                  icon="warning"
                  size="16"
                  class="mt-0.5 shrink-0 text-n-amber-11"
                />
                <p class="text-sm text-n-amber-11">
                  {{
                    replaceInstallationName(
                      t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.ZERO_ACCOUNTS')
                    )
                  }}
                </p>
              </div>

              <template v-else>
                <div v-if="accounts.length > 1" class="flex flex-col gap-1.5">
                  <label class="text-sm font-medium text-n-text-display">
                    {{
                      t('INTEGRATION_SETTINGS.YCLIENTS_CONNECT.SELECT_ACCOUNT')
                    }}
                  </label>
                  <select
                    v-model="selectedAccountId"
                    class="rounded-xl border border-n-border-glass-soft bg-n-glass-soft px-4 py-3 text-sm text-n-text-display outline-none transition-colors focus:border-n-brand focus:ring-1 focus:ring-n-brand"
                  >
                    <option
                      v-for="acc in accounts"
                      :key="acc.id"
                      :value="acc.id"
                    >
                      {{ acc.name }}
                    </option>
                  </select>
                </div>

                <NextButton
                  class="w-full"
                  :label="connectButtonLabel"
                  :loading="isSubmitting || isCheckingConnectionStatus"
                  :disabled="!canConnect"
                  @click="connect"
                />
              </template>

              <div
                v-if="isAlreadyConnected || status === 'already_connected'"
                class="flex items-start gap-2.5 rounded-xl border border-n-blue-7/30 bg-n-blue-3 p-3.5"
              >
                <fluent-icon
                  icon="checkmark-circle"
                  size="16"
                  class="mt-0.5 shrink-0 text-n-blue-11"
                />
                <p class="text-sm text-n-blue-11">
                  {{
                    t(
                      'INTEGRATION_SETTINGS.YCLIENTS_CONNECT.ALREADY_CONNECTED_HINT'
                    )
                  }}
                </p>
              </div>

              <!-- error -->
              <div
                v-if="status === 'error'"
                class="flex items-start gap-2.5 rounded-lg bg-n-ruby-3 p-3"
              >
                <fluent-icon
                  icon="warning"
                  size="16"
                  class="mt-0.5 shrink-0 text-n-ruby-11"
                />
                <p class="text-sm text-n-ruby-11">{{ errorMessage }}</p>
              </div>
            </template>
          </template>
        </div>
      </template>
    </div>
  </div>
</template>
