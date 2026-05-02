<script setup>
import { useRoute } from 'vue-router';

defineProps({
  keepAlive: {
    type: Boolean,
    default: true,
  },
});

const route = useRoute();
</script>

<template>
  <div
    class="flex flex-col w-full h-full min-h-0 m-2.5 pb-8 pt-4 px-3 sm:px-6 overflow-y-auto overflow-x-hidden bg-n-glass-strong backdrop-blur-glass-card backdrop-saturate-glass border border-n-border-glass rounded-card-lg shadow-glass-deep"
  >
    <div class="flex items-start w-full max-w-7xl mx-auto">
      <router-view v-slot="{ Component }">
        <keep-alive v-if="keepAlive">
          <component :is="Component" :key="route.fullPath" />
        </keep-alive>
        <component :is="Component" v-else :key="route.fullPath" />
      </router-view>
    </div>
  </div>
</template>
