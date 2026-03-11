<script setup>
import { computed } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useBranding } from 'shared/composables/useBranding';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const store = useStore();
const { t } = useI18n();
const { replaceInstallationName } = useBranding();

const globalConfig = computed(() => store.getters['globalConfig/get']);
const showSignupLink = computed(
  () => window.chatwootConfig.signupEnabled === 'true'
);

const features = [
  {
    icon: 'i-lucide-message-circle',
    titleKey: 'LANDING.FEATURES.OMNICHANNEL.TITLE',
    descKey: 'LANDING.FEATURES.OMNICHANNEL.DESCRIPTION',
  },
  {
    icon: 'i-lucide-users',
    titleKey: 'LANDING.FEATURES.COLLABORATION.TITLE',
    descKey: 'LANDING.FEATURES.COLLABORATION.DESCRIPTION',
  },
  {
    icon: 'i-lucide-zap',
    titleKey: 'LANDING.FEATURES.AUTOMATIONS.TITLE',
    descKey: 'LANDING.FEATURES.AUTOMATIONS.DESCRIPTION',
  },
  {
    icon: 'i-lucide-bar-chart-2',
    titleKey: 'LANDING.FEATURES.ANALYTICS.TITLE',
    descKey: 'LANDING.FEATURES.ANALYTICS.DESCRIPTION',
  },
];
</script>

<template>
  <main
    class="flex flex-col w-full min-h-screen bg-n-brand/5 dark:bg-n-background"
  >
    <!-- Nav -->
    <nav
      class="flex items-center justify-between w-full max-w-6xl px-6 py-4 mx-auto"
    >
      <div class="flex items-center gap-2">
        <img
          :src="globalConfig.logo"
          :alt="globalConfig.installationName"
          class="block w-auto h-6 dark:hidden"
        />
        <img
          v-if="globalConfig.logoDark"
          :src="globalConfig.logoDark"
          :alt="globalConfig.installationName"
          class="hidden w-auto h-6 dark:block"
        />
      </div>
      <div class="flex items-center gap-3">
        <router-link to="/app/login">
          <NextButton
            :label="t('LANDING.HERO.CTA_LOGIN')"
            variant="ghost"
            color="slate"
          />
        </router-link>
        <router-link v-if="showSignupLink" to="/app/auth/signup">
          <NextButton :label="t('LANDING.HERO.CTA_SIGNUP')" />
        </router-link>
      </div>
    </nav>

    <!-- Hero -->
    <section class="flex flex-col items-center px-6 py-20 text-center sm:py-32">
      <h1
        class="max-w-3xl text-4xl font-bold tracking-tight text-n-slate-12 sm:text-6xl"
      >
        {{ t('LANDING.HERO.TITLE') }}
      </h1>
      <p class="max-w-2xl mt-6 text-lg leading-8 text-n-slate-11">
        {{ t('LANDING.HERO.SUBTITLE') }}
      </p>
      <div class="flex gap-4 mt-10">
        <router-link v-if="showSignupLink" to="/app/auth/signup">
          <NextButton :label="t('LANDING.HERO.CTA_SIGNUP')" lg />
        </router-link>
        <router-link to="/app/login">
          <NextButton
            :label="t('LANDING.HERO.CTA_LOGIN')"
            lg
            variant="ghost"
            color="slate"
          />
        </router-link>
      </div>
    </section>

    <!-- Features -->
    <section class="w-full max-w-6xl px-6 py-16 mx-auto sm:py-24">
      <h2
        class="text-2xl font-semibold text-center text-n-slate-12 sm:text-3xl"
      >
        {{ t('LANDING.FEATURES.TITLE') }}
      </h2>
      <div class="grid gap-8 mt-12 sm:grid-cols-2 lg:grid-cols-4">
        <div
          v-for="feature in features"
          :key="feature.titleKey"
          class="flex flex-col items-center p-6 text-center rounded-xl bg-white dark:bg-n-solid-2 shadow-sm"
        >
          <div
            class="flex items-center justify-center rounded-lg size-12 bg-n-brand/10"
          >
            <Icon :icon="feature.icon" class="text-n-brand size-6" />
          </div>
          <h3 class="mt-4 text-base font-semibold text-n-slate-12">
            <!-- eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys -->
            {{ t(feature.titleKey) }}
          </h3>
          <p class="mt-2 text-sm leading-6 text-n-slate-11">
            <!-- eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys -->
            {{ t(feature.descKey) }}
          </p>
        </div>
      </div>
    </section>

    <!-- Footer -->
    <footer class="px-6 py-8 mt-auto text-center">
      <p class="text-sm text-n-slate-10">
        {{
          replaceInstallationName(
            t('LANDING.FOOTER.POWERED_BY', {
              installationName: globalConfig.installationName,
            })
          )
        }}
      </p>
    </footer>
  </main>
</template>
