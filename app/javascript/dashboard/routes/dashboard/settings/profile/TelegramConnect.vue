<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    NextButton,
  },
  data() {
    return {
      telegramChatId: '',
      inputStyles: {
        borderRadius: '0.75rem',
        padding: '0.375rem 0.75rem',
        fontSize: '0.875rem',
        marginBottom: '0.125rem',
      },
    };
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
    }),
  },
  watch: {
    currentUser: {
      handler(user) {
        this.telegramChatId = user?.telegram_chat_id || '';
      },
      immediate: true,
    },
  },
  methods: {
    async updateTelegramChatId() {
      try {
        await this.$store.dispatch('updateProfile', {
          telegram_chat_id: this.telegramChatId || null,
        });
        useAlert(
          this.$t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.UPDATE_SUCCESS')
        );
      } catch (error) {
        useAlert(
          error?.response?.data?.message ||
            this.$t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.UPDATE_ERROR')
        );
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <woot-input
      v-model="telegramChatId"
      :styles="inputStyles"
      :label="$t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.LABEL')"
      :placeholder="$t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.PLACEHOLDER')"
    />
    <p class="text-sm text-n-slate-11">
      {{ $t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.HINT') }}
    </p>
    <NextButton
      type="button"
      :label="$t('PROFILE_SETTINGS.FORM.TELEGRAM_CONNECT.SAVE')"
      @click="updateTelegramChatId"
    />
  </div>
</template>
