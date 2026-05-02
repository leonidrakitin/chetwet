<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SettingsHeader from './SettingsHeader.vue';
const props = defineProps({
  headerTitle: { type: String, default: '' },
  icon: { type: String, default: '' },
  keepAlive: { type: Boolean, default: true },
  showBackButton: { type: Boolean, default: false },
  backUrl: { type: [String, Object], default: '' },
});

const { t } = useI18n();

const showSettingsHeader = computed(
  () => props.headerTitle || props.icon || props.showBackButton
);
</script>

<template>
  <div
    class="flex flex-col w-full h-full min-h-0 m-2.5 bg-n-glass-strong backdrop-blur-glass-card backdrop-saturate-glass border border-n-border-glass rounded-card-lg shadow-glass-deep overflow-hidden"
  >
    <SettingsHeader
      v-if="showSettingsHeader"
      :icon="icon"
      :header-title="t(headerTitle)"
      :show-back-button="showBackButton"
      :back-url="backUrl"
      class="z-20 max-w-7xl w-full mx-auto"
    />

    <router-view v-slot="{ Component }" class="px-4 overflow-hidden">
      <component :is="Component" v-if="!keepAlive" :key="$route.fullPath" />
      <keep-alive v-else>
        <component :is="Component" :key="$route.fullPath" />
      </keep-alive>
    </router-view>
  </div>
</template>
