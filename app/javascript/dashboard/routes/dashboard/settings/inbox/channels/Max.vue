<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import PageHeader from '../../SettingsSubPageHeader.vue';

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const botToken = ref('');
const isSubmitting = ref(false);

const rules = { botToken: { required } };
const v$ = useVuelidate(rules, { botToken });

const createChannel = async () => {
  await v$.value.$validate();
  if (v$.value.$invalid) return;

  isSubmitting.value = true;
  try {
    const maxChannel = await store.dispatch('inboxes/createChannel', {
      channel: {
        type: 'max',
        bot_token: botToken.value,
      },
    });
    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: maxChannel.id },
    });
  } catch (error) {
    useAlert(
      error.message || t('INBOX_MGMT.ADD.MAX_CHANNEL.API.ERROR_MESSAGE')
    );
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.MAX_CHANNEL.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.MAX_CHANNEL.DESC')"
    />
    <form class="flex flex-wrap flex-col mx-0" @submit.prevent="createChannel">
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.botToken.$error }">
          {{ $t('INBOX_MGMT.ADD.MAX_CHANNEL.BOT_TOKEN.LABEL') }}
          <input
            v-model="botToken"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.MAX_CHANNEL.BOT_TOKEN.PLACEHOLDER')
            "
            @blur="v$.botToken.$touch"
          />
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.MAX_CHANNEL.BOT_TOKEN.SUBTITLE') }}
        </p>
      </div>

      <div class="w-full mt-4">
        <Button
          :is-loading="isSubmitting"
          type="submit"
          solid
          blue
          :label="$t('INBOX_MGMT.ADD.MAX_CHANNEL.SUBMIT_BUTTON')"
        />
      </div>
    </form>
  </div>
</template>
