<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, url } from '@vuelidate/validators';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useRouter } from 'vue-router';
import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const uiFlags = useStoreGetters('inboxes/getUIFlags');

const inboxName = ref('');
const phoneNumber = ref('');
const apiUrl = ref('');
const apiKey = ref('');
const instanceName = ref('');

const rules = {
  inboxName: { required },
  phoneNumber: { required, isPhoneE164OrEmpty },
  apiUrl: { required, url },
  apiKey: { required },
  instanceName: { required },
};

const v$ = useVuelidate(rules, {
  inboxName,
  phoneNumber,
  apiUrl,
  apiKey,
  instanceName,
});

const createChannel = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    const whatsappChannel = await store.dispatch('inboxes/createChannel', {
      name: inboxName.value.trim(),
      channel: {
        type: 'whatsapp',
        phone_number: phoneNumber.value,
        provider: 'evolution_api',
        provider_config: {
          api_key: apiKey.value,
          api_url: apiUrl.value.replace(/\/+$/, ''),
          instance_name: instanceName.value,
        },
      },
    });

    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: whatsappChannel.id },
    });
  } catch (error) {
    useAlert(error.message || t('INBOX_MGMT.ADD.WHATSAPP.API.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <form class="flex flex-wrap flex-col mx-0" @submit.prevent="createChannel">
    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.inboxName.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.LABEL') }}
        <input
          v-model="inboxName"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.PLACEHOLDER')"
          @blur="v$.inboxName.$touch"
        />
        <span v-if="v$.inboxName.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.phoneNumber.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.LABEL') }}
        <input
          v-model="phoneNumber"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.PLACEHOLDER')"
          @blur="v$.phoneNumber.$touch"
        />
        <span v-if="v$.phoneNumber.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.apiUrl.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION_API_URL.LABEL') }}
        <input
          v-model="apiUrl"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION_API_URL.PLACEHOLDER')
          "
          @blur="v$.apiUrl.$touch"
        />
        <span v-if="v$.apiUrl.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION_API_URL.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.apiKey.$error }">
        <span>
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.API_KEY.LABEL') }}
        </span>
        <input
          v-model="apiKey"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.API_KEY.PLACEHOLDER')"
          @blur="v$.apiKey.$touch"
        />
        <span v-if="v$.apiKey.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.API_KEY.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.instanceName.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION_INSTANCE_NAME.LABEL') }}
        <input
          v-model="instanceName"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION_INSTANCE_NAME.PLACEHOLDER')
          "
          @blur="v$.instanceName.$touch"
        />
        <span v-if="v$.instanceName.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION_INSTANCE_NAME.ERROR') }}
        </span>
      </label>
    </div>

    <div class="w-full mt-4">
      <NextButton
        :is-loading="uiFlags.isCreating"
        type="submit"
        solid
        blue
        :label="$t('INBOX_MGMT.ADD.WHATSAPP.SUBMIT_BUTTON')"
      />
    </div>
  </form>
</template>
