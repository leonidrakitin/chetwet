<script setup>
defineProps({
  keepAlive: {
    type: Boolean,
    default: true,
  },
});
</script>

<template>
  <div
    class="flex flex-col justify-between flex-1 h-full m-2.5 overflow-auto bg-n-glass-strong backdrop-blur-glass-card backdrop-saturate-glass border border-n-border-glass rounded-card-lg shadow-glass-deep"
  >
    <router-view v-slot="{ Component }">
      <keep-alive v-if="keepAlive">
        <component :is="Component" />
      </keep-alive>
      <component :is="Component" v-else />
    </router-view>
  </div>
</template>
