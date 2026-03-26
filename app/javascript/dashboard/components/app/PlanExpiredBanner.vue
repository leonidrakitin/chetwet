<script>
import { mapGetters } from 'vuex';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAccount } from 'dashboard/composables/useAccount';
import Banner from 'dashboard/components/ui/Banner.vue';

export default {
  components: { Banner },
  setup() {
    const { isAdmin } = useAdmin();
    const { accountId } = useAccount();
    return { accountId, isAdmin };
  },
  computed: {
    ...mapGetters({
      getAccount: 'accounts/getAccount',
    }),
    shouldShowBanner() {
      if (!this.isAdmin) return false;
      return this.isPlanExpired();
    },
    bannerMessage() {
      return this.$t('GENERAL_SETTINGS.PLAN_EXPIRED');
    },
  },
  methods: {
    isPlanExpired() {
      const account = this.getAccount(this.accountId);
      if (!account?.custom_attributes?.plan_expires_at) return false;

      const expiresAt = new Date(account.custom_attributes.plan_expires_at);
      return !Number.isNaN(expiresAt.getTime()) && expiresAt < new Date();
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <Banner
    v-if="shouldShowBanner"
    color-scheme="alert"
    :banner-message="bannerMessage"
  />
</template>
