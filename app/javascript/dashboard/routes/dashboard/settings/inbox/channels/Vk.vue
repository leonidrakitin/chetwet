<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import vkClient from 'dashboard/api/channel/vkClient';
import Button from 'dashboard/components-next/button/Button.vue';
import PageHeader from '../../SettingsSubPageHeader.vue';
import { useStore } from 'dashboard/composables/store';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

// Use raw route param (string) — not Number() — to support non-numeric account IDs.
const accountId = route.params.accountId;

const VK_OAUTH_DEVICE_ID_KEY = 'vk_oauth_device_id';
const VK_OAUTH_STATE_NONCE_COOKIE = 'vk_oauth_state_nonce';

const step = ref('connect');
const hasError = ref(false);
const errorMessage = ref('');
const isRequestingAuthorization = ref(false);
const isLoadingGroups = ref(false);
const isActivating = ref(false);
const isSubmitting = ref(false);
const groups = ref([]);
const tokenData = ref(null);
const selectedGroupId = ref(null);
const oauthEnabled = ref(false);
const hasGroup = ref(null);

// Manual mode fields
const groupId = ref('');
const accessToken = ref('');
const secret = ref('');

const manualRules = {
  groupId: { required },
  accessToken: { required },
};
const v$ = useVuelidate(manualRules, { groupId, accessToken });

const allManualSetupSteps = computed(() => [
  t('INBOX_MGMT.ADD.VK_CHANNEL.MANUAL_SETUP.STEP_1'),
  t('INBOX_MGMT.ADD.VK_CHANNEL.MANUAL_SETUP.STEP_2'),
  t('INBOX_MGMT.ADD.VK_CHANNEL.MANUAL_SETUP.STEP_3'),
  t('INBOX_MGMT.ADD.VK_CHANNEL.MANUAL_SETUP.STEP_4'),
  t('INBOX_MGMT.ADD.VK_CHANNEL.MANUAL_SETUP.STEP_5'),
  t('INBOX_MGMT.ADD.VK_CHANNEL.MANUAL_SETUP.STEP_6'),
  t('INBOX_MGMT.ADD.VK_CHANNEL.MANUAL_SETUP.STEP_7'),
]);

// When user already has a group — skip the "create community" step (step 1)
const manualSetupSteps = computed(() =>
  hasGroup.value
    ? allManualSetupSteps.value.slice(1)
    : allManualSetupSteps.value
);

const createGroupSteps = computed(() => [
  t('INBOX_MGMT.ADD.VK_CHANNEL.CREATE_GROUP.STEP_1'),
  t('INBOX_MGMT.ADD.VK_CHANNEL.CREATE_GROUP.STEP_2'),
  t('INBOX_MGMT.ADD.VK_CHANNEL.CREATE_GROUP.STEP_3'),
  t('INBOX_MGMT.ADD.VK_CHANNEL.CREATE_GROUP.STEP_4'),
]);

// --- PKCE helpers (Web Crypto API) ---
const generateCodeVerifier = () => {
  const array = new Uint8Array(64);
  crypto.getRandomValues(array);
  return btoa(String.fromCharCode(...array))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
};

const generateCodeChallenge = async verifier => {
  const encoder = new TextEncoder();
  const data = encoder.encode(verifier);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return btoa(String.fromCharCode(...new Uint8Array(digest)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
};

// --- Load groups from backend ---
const loadGroups = async tokenHandle => {
  isLoadingGroups.value = true;
  try {
    const response = await vkClient.getGroups(tokenHandle);
    groups.value = response.data.groups || [];
    tokenData.value = response.data.token_data;
    if (groups.value.length === 0) {
      hasError.value = true;
      errorMessage.value = t('INBOX_MGMT.ADD.VK_CHANNEL.NO_GROUPS');
    }
  } catch {
    hasError.value = true;
    errorMessage.value = t('INBOX_MGMT.ADD.VK_CHANNEL.API.ERROR_MESSAGE');
  } finally {
    isLoadingGroups.value = false;
  }
};

// --- Exchange code for tokens via backend ---
const exchangeCodeForTokens = async (code, deviceId, stateParam) => {
  const codeVerifier = localStorage.getItem('vk_pkce_verifier');
  if (!codeVerifier) {
    hasError.value = true;
    errorMessage.value = 'PKCE verifier not found. Please try again.';
    return;
  }
  localStorage.removeItem('vk_pkce_verifier');

  const storedDeviceId = sessionStorage.getItem(VK_OAUTH_DEVICE_ID_KEY);
  sessionStorage.removeItem(VK_OAUTH_DEVICE_ID_KEY);
  const effectiveDeviceId = deviceId || storedDeviceId;

  isLoadingGroups.value = true;
  step.value = 'groups';
  try {
    const exchangeResponse = await vkClient.exchangeCode({
      code,
      device_id: effectiveDeviceId,
      code_verifier: codeVerifier,
      ...(stateParam && { state: stateParam }),
    });
    const { token_handle: tokenHandle } = exchangeResponse.data;
    await loadGroups(tokenHandle);
  } catch {
    hasError.value = true;
    errorMessage.value = t('INBOX_MGMT.ADD.VK_CHANNEL.API.ERROR_MESSAGE');
    isLoadingGroups.value = false;
  }
};

onMounted(async () => {
  const urlParams = new URLSearchParams(window.location.search);
  const error = urlParams.get('error_message');
  const code = urlParams.get('code');
  const deviceId = urlParams.get('device_id');
  const stateParam = urlParams.get('state');

  window.history.replaceState({}, document.title, window.location.pathname);

  oauthEnabled.value = !!window.chatwootConfig?.vkIdClientId;

  if (error) {
    hasError.value = true;
    errorMessage.value = error;
    return;
  }

  if (code && oauthEnabled.value) {
    await exchangeCodeForTokens(code, deviceId, stateParam);
  }
});

// --- OAuth: generate PKCE + redirect to VK ID ---
const requestAuthorization = async () => {
  isRequestingAuthorization.value = true;
  try {
    const codeVerifier = generateCodeVerifier();
    const codeChallenge = await generateCodeChallenge(codeVerifier);

    localStorage.setItem('vk_pkce_verifier', codeVerifier);

    const deviceId = crypto.randomUUID();
    sessionStorage.setItem(VK_OAUTH_DEVICE_ID_KEY, deviceId);

    const clientId = window.chatwootConfig.vkIdClientId;
    const redirectUri = `${window.location.origin}/vk/callback`;

    // State format: "accountId:randomHex" — callback parses accountId for redirect
    const stateArray = new Uint8Array(16);
    crypto.getRandomValues(stateArray);
    const randomHex = Array.from(stateArray, b =>
      b.toString(16).padStart(2, '0')
    ).join('');
    const stateToken = `${accountId}:${randomHex}`;
    const securePart = window.location.protocol === 'https:' ? '; secure' : '';
    document.cookie = `${VK_OAUTH_STATE_NONCE_COOKIE}=${stateToken}; path=/; max-age=600; samesite=lax${securePart}`;

    const params = new URLSearchParams({
      client_id: clientId,
      redirect_uri: redirectUri,
      response_type: 'code',
      scope: 'groups messages',
      state: stateToken,
      code_challenge: codeChallenge,
      code_challenge_method: 'S256',
      device_id: deviceId,
    });

    window.location.href = `https://id.vk.com/authorize?${params.toString()}`;
  } catch {
    useAlert(t('INBOX_MGMT.ADD.VK_CHANNEL.API.ERROR_MESSAGE'));
    isRequestingAuthorization.value = false;
  }
};

const activateGroup = async group => {
  if (!tokenData.value) return;

  selectedGroupId.value = group.id;
  isActivating.value = true;
  try {
    const expiresIn = tokenData.value.expires_in;
    const expiresAt = expiresIn
      ? new Date(Date.now() + expiresIn * 1000).toISOString()
      : null;

    const vkChannel = await store.dispatch('inboxes/createChannel', {
      channel: {
        type: 'vk',
        group_id: String(group.id),
        access_token: tokenData.value.access_token,
        refresh_token: tokenData.value.refresh_token,
        token_expires_at: expiresAt,
        vk_user_id: tokenData.value.user_id,
      },
    });
    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: vkChannel.id },
    });
  } catch (err) {
    useAlert(err.message || t('INBOX_MGMT.ADD.VK_CHANNEL.API.ERROR_MESSAGE'));
    isActivating.value = false;
    selectedGroupId.value = null;
  }
};

const createChannelManually = async () => {
  await v$.value.$validate();
  if (v$.value.$invalid) {
    return;
  }

  isSubmitting.value = true;
  try {
    const vkChannel = await store.dispatch('inboxes/createChannel', {
      channel: {
        type: 'vk',
        group_id: groupId.value,
        access_token: accessToken.value,
        secret: secret.value || undefined,
      },
    });
    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: vkChannel.id },
    });
  } catch (error) {
    useAlert(error.message || t('INBOX_MGMT.ADD.VK_CHANNEL.API.ERROR_MESSAGE'));
    isSubmitting.value = false;
  }
};

const resetAndRetry = () => {
  hasError.value = false;
  errorMessage.value = '';
  step.value = 'connect';
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.VK_CHANNEL.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.VK_CHANNEL.DESC')"
    />

    <!-- Error state -->
    <div v-if="hasError" class="max-w-lg mx-auto text-center mt-8">
      <h5 class="text-n-slate-12 mb-2">
        {{ errorMessage }}
      </h5>
      <Button
        class="mt-4"
        :label="$t('INBOX_MGMT.ADD.VK_CHANNEL.RETRY')"
        @click="resetAndRetry"
      />
    </div>

    <!-- Step 0: group status selection (only for fresh connect flow) -->
    <div
      v-else-if="hasGroup === null && step === 'connect'"
      class="grid grid-cols-2 gap-4 mt-4"
    >
      <button
        class="text-left flex flex-col p-5 rounded-2xl outline outline-1 outline-n-weak hover:outline-n-brand transition-all cursor-pointer"
        @click="hasGroup = true"
      >
        <span class="font-semibold text-sm text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.HAS_GROUP.YES') }}
        </span>
        <span class="text-xs text-n-slate-11 mt-1">
          {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.HAS_GROUP.YES_DESC') }}
        </span>
      </button>
      <button
        class="text-left flex flex-col p-5 rounded-2xl outline outline-1 outline-n-weak hover:outline-n-brand transition-all cursor-pointer"
        @click="hasGroup = false"
      >
        <span class="font-semibold text-sm text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.HAS_GROUP.NO') }}
        </span>
        <span class="text-xs text-n-slate-11 mt-1">
          {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.HAS_GROUP.NO_DESC') }}
        </span>
      </button>
    </div>

    <!-- OAuth Mode: Step 1 - Connect VK -->
    <div v-else-if="oauthEnabled && step === 'connect'" class="mt-4">
      <!-- No group yet: show create-group instructions first -->
      <div
        v-if="!hasGroup"
        class="rounded-2xl outline outline-1 outline-n-weak p-5 mb-6 bg-n-alpha-1"
      >
        <p class="text-sm font-semibold text-n-slate-12 mb-4">
          {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.CREATE_GROUP.TITLE') }}
        </p>
        <ol class="space-y-3">
          <li
            v-for="(createStep, index) in createGroupSteps"
            :key="index"
            class="flex items-start gap-3"
          >
            <span
              class="flex-shrink-0 w-5 h-5 rounded-full bg-n-brand text-white text-xs font-semibold flex items-center justify-center mt-0.5"
            >
              {{ index + 1 }}
            </span>
            <span
              v-dompurify-html="createStep"
              class="text-sm text-n-slate-11 leading-5"
            />
          </li>
        </ol>
      </div>

      <div
        class="flex flex-col items-center justify-center px-8 py-10 text-center rounded-2xl outline outline-1 outline-n-weak"
      >
        <h6 class="text-2xl font-medium">
          {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.CONNECT_TITLE') }}
        </h6>
        <p class="py-6 text-sm text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.CONNECT_HELP') }}
        </p>
        <Button
          class="text-white !rounded-full !px-6 bg-[#0077ff]"
          lg
          icon="i-woot-vk"
          :disabled="isRequestingAuthorization"
          :is-loading="isRequestingAuthorization"
          :label="$t('INBOX_MGMT.ADD.VK_CHANNEL.CONNECT_BUTTON')"
          @click="requestAuthorization"
        />
      </div>
    </div>

    <!-- OAuth Mode: Step 2 - Group selection -->
    <div v-else-if="oauthEnabled && step === 'groups'" class="mt-4">
      <div v-if="isLoadingGroups" class="flex justify-center py-10">
        <span class="text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.LOADING_GROUPS') }}
        </span>
      </div>
      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <div
          v-for="group in groups"
          :key="group.id"
          class="flex items-center gap-3 p-4 rounded-xl border border-n-weak hover:border-n-slate-7 cursor-pointer transition-colors"
          @click="activateGroup(group)"
        >
          <img
            v-if="group.photo_50"
            :src="group.photo_50"
            :alt="group.name"
            class="w-10 h-10 rounded-full flex-shrink-0"
          />
          <div
            v-else
            class="w-10 h-10 rounded-full bg-n-slate-3 flex-shrink-0"
          />
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-n-slate-12 truncate">
              {{ group.name }}
            </p>
            <p v-if="group.members_count" class="text-xs text-n-slate-11">
              {{
                $t('INBOX_MGMT.ADD.VK_CHANNEL.MEMBERS', {
                  count: group.members_count,
                })
              }}
            </p>
          </div>
          <Button
            xs
            solid
            blue
            :is-loading="isActivating && selectedGroupId === group.id"
            :disabled="isActivating"
            :label="$t('INBOX_MGMT.ADD.VK_CHANNEL.ACTIVATE')"
          />
        </div>
      </div>
    </div>

    <!-- Manual Mode: Form -->
    <div v-else-if="!oauthEnabled" class="mx-0 flex-col">
      <!-- No group yet: show create-group instructions -->
      <div
        v-if="!hasGroup"
        class="rounded-2xl outline outline-1 outline-n-weak p-5 mb-6 bg-n-alpha-1"
      >
        <p class="text-sm font-semibold text-n-slate-12 mb-4">
          {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.CREATE_GROUP.TITLE') }}
        </p>
        <ol class="space-y-3">
          <li
            v-for="(createStep, index) in createGroupSteps"
            :key="index"
            class="flex items-start gap-3"
          >
            <span
              class="flex-shrink-0 w-5 h-5 rounded-full bg-n-brand text-white text-xs font-semibold flex items-center justify-center mt-0.5"
            >
              {{ index + 1 }}
            </span>
            <span
              v-dompurify-html="createStep"
              class="text-sm text-n-slate-11 leading-5"
            />
          </li>
        </ol>
      </div>

      <div
        class="rounded-2xl outline outline-1 outline-n-weak p-5 mb-6 bg-n-alpha-1"
      >
        <p class="text-sm font-semibold text-n-slate-12 mb-1">
          {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.MANUAL_SETUP.TITLE') }}
        </p>
        <p class="text-sm text-n-slate-11 mb-4">
          {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.MANUAL_SETUP.INTRO') }}
        </p>
        <ol class="space-y-3">
          <li
            v-for="(setupStep, index) in manualSetupSteps"
            :key="index"
            class="flex items-start gap-3"
          >
            <span
              class="flex-shrink-0 w-5 h-5 rounded-full bg-n-brand text-white text-xs font-semibold flex items-center justify-center mt-0.5"
            >
              {{ index + 1 }}
            </span>
            <span
              v-dompurify-html="setupStep"
              class="text-sm text-n-slate-11 leading-5"
            />
          </li>
        </ol>
        <p
          v-dompurify-html="$t('INBOX_MGMT.ADD.VK_CHANNEL.MANUAL_SETUP.LINKS')"
          class="text-sm text-n-slate-11 mt-4 pl-8"
        />
      </div>
      <form
        class="flex flex-wrap flex-col"
        @submit.prevent="createChannelManually"
      >
        <div class="flex-shrink-0 flex-grow-0">
          <label :class="{ error: v$.groupId.$error }">
            {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.GROUP_ID.LABEL') }}
            <input
              v-model="groupId"
              type="text"
              :placeholder="
                $t('INBOX_MGMT.ADD.VK_CHANNEL.GROUP_ID.PLACEHOLDER')
              "
              @blur="v$.groupId.$touch"
            />
          </label>
          <p class="help-text">
            {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.GROUP_ID.SUBTITLE') }}
          </p>
        </div>

        <div class="flex-shrink-0 flex-grow-0 mt-4">
          <label :class="{ error: v$.accessToken.$error }">
            {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.ACCESS_TOKEN.LABEL') }}
            <input
              v-model="accessToken"
              type="text"
              :placeholder="
                $t('INBOX_MGMT.ADD.VK_CHANNEL.ACCESS_TOKEN.PLACEHOLDER')
              "
              @blur="v$.accessToken.$touch"
            />
          </label>
          <p class="help-text">
            {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.ACCESS_TOKEN.SUBTITLE') }}
          </p>
        </div>

        <div class="flex-shrink-0 flex-grow-0 mt-4">
          <label>
            {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.SECRET.LABEL') }}
            <input
              v-model="secret"
              type="text"
              :placeholder="$t('INBOX_MGMT.ADD.VK_CHANNEL.SECRET.PLACEHOLDER')"
            />
          </label>
          <p class="help-text">
            {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.SECRET.SUBTITLE') }}
          </p>
        </div>

        <div class="w-full mt-4">
          <Button
            :is-loading="isSubmitting"
            type="submit"
            solid
            blue
            icon="i-woot-vk"
            :label="$t('INBOX_MGMT.ADD.VK_CHANNEL.SUBMIT_BUTTON')"
          />
        </div>
      </form>
    </div>
  </div>
</template>
