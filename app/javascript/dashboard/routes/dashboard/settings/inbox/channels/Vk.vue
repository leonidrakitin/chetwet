<script setup>
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import { useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import PageHeader from '../../SettingsSubPageHeader.vue';

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const groupId = ref('');
const accessToken = ref('');
const secret = ref('');

const rules = {
  groupId: { required },
  accessToken: { required },
};
const v$ = useVuelidate(rules, { groupId, accessToken });

const uiFlags = computed(() => store.getters['inboxes/getUIFlags']);

const createChannel = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) {
    return;
  }

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
      params: {
        page: 'new',
        inbox_id: vkChannel.id,
      },
    });
  } catch (error) {
    useAlert(error.message || t('INBOX_MGMT.ADD.VK_CHANNEL.API.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.VK_CHANNEL.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.VK_CHANNEL.DESC')"
    />
    <form
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="createChannel()"
    >
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.groupId.$error }">
          {{ $t('INBOX_MGMT.ADD.VK_CHANNEL.GROUP_ID.LABEL') }}
          <input
            v-model="groupId"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.VK_CHANNEL.GROUP_ID.PLACEHOLDER')"
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
          :is-loading="uiFlags.isCreating"
          type="submit"
          solid
          blue
          icon="i-woot-vk"
          :label="$t('INBOX_MGMT.ADD.VK_CHANNEL.SUBMIT_BUTTON')"
        />
      </div>
    </form>
  </div>
</template>
