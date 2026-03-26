<script>
import Banner from 'dashboard/components/ui/Banner.vue';

export default {
  components: { Banner },
  computed: {
    shouldShowBanner() {
      return false;
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <Banner v-if="shouldShowBanner" color-scheme="alert" />
</template>
