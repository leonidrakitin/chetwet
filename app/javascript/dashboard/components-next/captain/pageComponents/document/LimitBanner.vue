<script setup>
import { computed } from 'vue';
import Banner from 'dashboard/components-next/banner/Banner.vue';

const showBanner = computed(() => false);
</script>

<template>
  <Banner v-show="showBanner" color="amber">
    {{ $t('CAPTAIN.BANNER.DOCUMENTS') }}
  </Banner>
</template>
