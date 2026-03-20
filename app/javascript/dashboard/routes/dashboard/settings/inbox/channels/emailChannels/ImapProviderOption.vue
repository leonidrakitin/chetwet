<script setup>
import { ref, computed } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { required, email } from '@vuelidate/validators';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import PageHeader from '../../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  providerConfig: {
    type: Object,
    required: true,
  },
});

const store = useStore();
const router = useRouter();
const { t } = useI18n();

const channelName = ref('');
const emailAddress = ref('');
const password = ref('');

const rules = {
  channelName: { required },
  emailAddress: { required, email },
  password: { required },
};

const v$ = useVuelidate(rules, { channelName, emailAddress, password });

const uiFlags = computed(() => store.getters['inboxes/getUIFlags']);

const providerLabel = computed(() => props.providerConfig.label);

async function createChannel() {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  const config = props.providerConfig;

  try {
    const inbox = await store.dispatch('inboxes/createChannel', {
      name: channelName.value.trim(),
      channel: {
        type: 'email',
        email: emailAddress.value,
        provider: config.key,
        imap_enabled: true,
        imap_login: emailAddress.value,
        imap_password: password.value,
        imap_address: config.imap.address,
        imap_port: config.imap.port,
        imap_enable_ssl: config.imap.ssl,
        smtp_enabled: true,
        smtp_login: emailAddress.value,
        smtp_password: password.value,
        smtp_address: config.smtp.address,
        smtp_port: config.smtp.port,
        smtp_domain: config.smtp.domain,
        smtp_enable_ssl_tls: config.smtp.sslTls,
        smtp_enable_starttls_auto: config.smtp.starttls,
        smtp_openssl_verify_mode: 'none',
        smtp_authentication: config.smtp.authentication,
      },
    });

    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: inbox.id },
    });
  } catch (error) {
    const errorMessage =
      error?.message || t('INBOX_MGMT.ADD.IMAP_PROVIDER.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  }
}
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="
        $t('INBOX_MGMT.ADD.IMAP_PROVIDER.TITLE', {
          provider: providerLabel,
        })
      "
      :header-content="
        $t('INBOX_MGMT.ADD.IMAP_PROVIDER.DESC', {
          provider: providerLabel,
        })
      "
    />
    <form class="flex flex-wrap flex-col mx-0" @submit.prevent="createChannel">
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.channelName.$error }">
          {{ $t('INBOX_MGMT.ADD.EMAIL_CHANNEL.CHANNEL_NAME.LABEL') }}
          <input
            v-model="channelName"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.EMAIL_CHANNEL.CHANNEL_NAME.PLACEHOLDER')
            "
            @blur="v$.channelName.$touch"
          />
          <span v-if="v$.channelName.$error" class="message">
            {{ $t('INBOX_MGMT.ADD.EMAIL_CHANNEL.CHANNEL_NAME.ERROR') }}
          </span>
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.emailAddress.$error }">
          {{ $t('INBOX_MGMT.ADD.EMAIL_CHANNEL.EMAIL.LABEL') }}
          <input
            v-model="emailAddress"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.EMAIL_CHANNEL.EMAIL.PLACEHOLDER')"
            @blur="v$.emailAddress.$touch"
          />
          <span v-if="v$.emailAddress.$error" class="message">
            {{ $t('INBOX_MGMT.ADD.EMAIL_CHANNEL.CHANNEL_NAME.ERROR') }}
          </span>
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0 mb-4">
        <label :class="{ error: v$.password.$error }">
          {{ $t('INBOX_MGMT.ADD.IMAP_PROVIDER.PASSWORD.LABEL') }}
          <input
            v-model="password"
            type="password"
            :placeholder="
              $t('INBOX_MGMT.ADD.IMAP_PROVIDER.PASSWORD.PLACEHOLDER')
            "
            @blur="v$.password.$touch"
          />
          <p class="help-text">
            {{ $t('INBOX_MGMT.ADD.IMAP_PROVIDER.PASSWORD.SUBTITLE') }}
          </p>
          <span v-if="v$.password.$error" class="message">
            {{ $t('INBOX_MGMT.ADD.EMAIL_CHANNEL.CHANNEL_NAME.ERROR') }}
          </span>
        </label>
      </div>

      <div class="w-full mt-4">
        <NextButton
          :is-loading="uiFlags.isCreating"
          type="submit"
          solid
          blue
          :label="
            $t('INBOX_MGMT.ADD.IMAP_PROVIDER.SUBMIT_BUTTON', {
              provider: providerLabel,
            })
          "
        />
      </div>
    </form>
  </div>
</template>
