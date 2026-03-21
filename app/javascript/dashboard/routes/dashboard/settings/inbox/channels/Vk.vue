<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import vkClient from 'dashboard/api/channel/vkClient';
import Button from 'dashboard/components-next/button/Button.vue';
import PageHeader from '../../SettingsSubPageHeader.vue';
import { useStore } from 'dashboard/composables/store';

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const step = ref('connect');
const hasError = ref(false);
const errorMessage = ref('');
const isRequestingAuthorization = ref(false);
const isLoadingGroups = ref(false);
const isActivating = ref(false);
const groups = ref([]);
const tokenData = ref(null);
const selectedGroupId = ref(null);

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

onMounted(async () => {
  const urlParams = new URLSearchParams(window.location.search);
  const error = urlParams.get('error_message');
  const tokenHandle = urlParams.get('token_handle');

  window.history.replaceState({}, document.title, window.location.pathname);

  if (error) {
    hasError.value = true;
    errorMessage.value = error;
    return;
  }

  if (tokenHandle) {
    step.value = 'groups';
    await loadGroups(tokenHandle);
  }
});

const requestAuthorization = async () => {
  isRequestingAuthorization.value = true;
  try {
    const response = await vkClient.generateAuthorization();
    const {
      data: { url },
    } = response;
    window.location.href = url;
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

    <!-- Step 1: Connect VK -->
    <div
      v-else-if="step === 'connect'"
      class="flex flex-col items-center justify-center px-8 py-10 text-center rounded-2xl outline outline-1 outline-n-weak mt-4"
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

    <!-- Step 2: Group selection -->
    <div v-else-if="step === 'groups'" class="mt-4">
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
  </div>
</template>
