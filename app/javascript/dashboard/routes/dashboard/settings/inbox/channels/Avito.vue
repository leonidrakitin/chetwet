<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import router from '../../../../index';
import PageHeader from '../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    PageHeader,
    NextButton,
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      name: '',
      clientId: '',
      clientSecret: '',
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
    }),
  },
  validations: {
    name: { required },
    clientId: { required },
    clientSecret: { required },
  },
  methods: {
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const avitoChannel = await this.$store.dispatch(
          'inboxes/createChannel',
          {
            name: this.name?.trim(),
            channel: {
              type: 'avito',
              client_id: this.clientId,
              client_secret: this.clientSecret,
            },
          }
        );

        router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: avitoChannel.id,
          },
        });
      } catch (error) {
        useAlert(
          error.message ||
            this.$t('INBOX_MGMT.ADD.AVITO_CHANNEL.API.ERROR_MESSAGE')
        );
      }
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.AVITO_CHANNEL.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.AVITO_CHANNEL.DESC')"
    />
    <form
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="createChannel()"
    >
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.name.$error }">
          {{ $t('INBOX_MGMT.ADD.AVITO_CHANNEL.NAME.LABEL') }}
          <input
            v-model="name"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.AVITO_CHANNEL.NAME.PLACEHOLDER')"
            @blur="v$.name.$touch"
          />
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0 mt-4">
        <label :class="{ error: v$.clientId.$error }">
          {{ $t('INBOX_MGMT.ADD.AVITO_CHANNEL.CLIENT_ID.LABEL') }}
          <input
            v-model="clientId"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.AVITO_CHANNEL.CLIENT_ID.PLACEHOLDER')
            "
            @blur="v$.clientId.$touch"
          />
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.AVITO_CHANNEL.CLIENT_ID.SUBTITLE') }}
        </p>
      </div>

      <div class="flex-shrink-0 flex-grow-0 mt-4">
        <label :class="{ error: v$.clientSecret.$error }">
          {{ $t('INBOX_MGMT.ADD.AVITO_CHANNEL.CLIENT_SECRET.LABEL') }}
          <input
            v-model="clientSecret"
            type="password"
            :placeholder="
              $t('INBOX_MGMT.ADD.AVITO_CHANNEL.CLIENT_SECRET.PLACEHOLDER')
            "
            @blur="v$.clientSecret.$touch"
          />
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.AVITO_CHANNEL.CLIENT_SECRET.SUBTITLE') }}
        </p>
      </div>

      <div class="w-full mt-4">
        <NextButton
          :is-loading="uiFlags.isCreating"
          type="submit"
          solid
          blue
          :label="$t('INBOX_MGMT.ADD.AVITO_CHANNEL.SUBMIT_BUTTON')"
        />
      </div>
    </form>
  </div>
</template>
