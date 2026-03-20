<script setup>
import { computed } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useBranding } from 'shared/composables/useBranding';
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
    icon: 'i-lucide-inbox',
    titleKey: 'LANDING.FEATURES.OMNICHANNEL.TITLE',
    descKey: 'LANDING.FEATURES.OMNICHANNEL.DESCRIPTION',
    color: 'bg-blue-100 dark:bg-blue-900/30',
    iconColor: 'text-blue-600 dark:text-blue-400',
  },
  {
    icon: 'i-lucide-bell-ring',
    titleKey: 'LANDING.FEATURES.TEMPLATES.TITLE',
    descKey: 'LANDING.FEATURES.TEMPLATES.DESCRIPTION',
    color: 'bg-amber-100 dark:bg-amber-900/30',
    iconColor: 'text-amber-600 dark:text-amber-400',
  },
  {
    icon: 'i-lucide-send',
    titleKey: 'LANDING.FEATURES.TELEGRAM.TITLE',
    descKey: 'LANDING.FEATURES.TELEGRAM.DESCRIPTION',
    color: 'bg-sky-100 dark:bg-sky-900/30',
    iconColor: 'text-sky-600 dark:text-sky-400',
  },
  {
    icon: 'i-lucide-calendar-check',
    titleKey: 'LANDING.FEATURES.YCLIENTS.TITLE',
    descKey: 'LANDING.FEATURES.YCLIENTS.DESCRIPTION',
    color: 'bg-emerald-100 dark:bg-emerald-900/30',
    iconColor: 'text-emerald-600 dark:text-emerald-400',
  },
  {
    icon: 'i-lucide-zap',
    titleKey: 'LANDING.FEATURES.AUTOMATIONS.TITLE',
    descKey: 'LANDING.FEATURES.AUTOMATIONS.DESCRIPTION',
    color: 'bg-purple-100 dark:bg-purple-900/30',
    iconColor: 'text-purple-600 dark:text-purple-400',
  },
  {
    icon: 'i-lucide-bar-chart-2',
    titleKey: 'LANDING.FEATURES.ANALYTICS.TITLE',
    descKey: 'LANDING.FEATURES.ANALYTICS.DESCRIPTION',
    color: 'bg-rose-100 dark:bg-rose-900/30',
    iconColor: 'text-rose-600 dark:text-rose-400',
  },
];

const steps = [
  {
    number: '01',
    icon: 'i-lucide-plug',
    titleKey: 'LANDING.HOW_IT_WORKS.STEP_1.TITLE',
    descKey: 'LANDING.HOW_IT_WORKS.STEP_1.DESCRIPTION',
  },
  {
    number: '02',
    icon: 'i-lucide-settings',
    titleKey: 'LANDING.HOW_IT_WORKS.STEP_2.TITLE',
    descKey: 'LANDING.HOW_IT_WORKS.STEP_2.DESCRIPTION',
  },
  {
    number: '03',
    icon: 'i-lucide-heart',
    titleKey: 'LANDING.HOW_IT_WORKS.STEP_3.TITLE',
    descKey: 'LANDING.HOW_IT_WORKS.STEP_3.DESCRIPTION',
  },
];

const stats = [
  {
    valueKey: 'LANDING.STATS.CHANNELS',
    descKey: 'LANDING.STATS.CHANNELS_DESC',
  },
  {
    valueKey: 'LANDING.STATS.AUTOMATIONS',
    descKey: 'LANDING.STATS.AUTOMATIONS_DESC',
  },
  { valueKey: 'LANDING.STATS.UPTIME', descKey: 'LANDING.STATS.UPTIME_DESC' },
];
</script>

<template>
  <div class="relative min-h-screen bg-[#F4F3EE] dark:bg-n-background">
    <!-- Decorative blobs -->
    <div
      class="pointer-events-none absolute left-[-10%] top-[5%] h-[500px] w-[500px] rounded-full bg-[#D97757]/8 blur-[120px]"
    />
    <div
      class="pointer-events-none absolute right-[-5%] top-[20%] h-[400px] w-[400px] rounded-full bg-blue-400/6 blur-[100px]"
    />

    <!-- Nav -->
    <nav
      class="sticky top-0 z-50 border-b border-[#E6E4DD] bg-[#F4F3EE]/80 backdrop-blur-xl dark:border-n-strong dark:bg-n-background/80"
    >
      <div
        class="mx-auto flex max-w-6xl items-center justify-between px-6 py-4"
      >
        <div class="flex items-center gap-2">
          <img
            :src="globalConfig.logo"
            :alt="globalConfig.installationName"
            class="block h-7 w-auto dark:hidden"
          />
          <img
            v-if="globalConfig.logoDark"
            :src="globalConfig.logoDark"
            :alt="globalConfig.installationName"
            class="hidden h-7 w-auto dark:block"
          />
        </div>
        <div class="flex items-center gap-3">
          <router-link
            to="/app/login"
            class="rounded-xl px-4 py-2 text-sm font-medium text-[#3F3E3A] transition-colors hover:bg-black/5 dark:text-n-slate-12 dark:hover:bg-white/5"
          >
            {{ t('LANDING.HERO.CTA_LOGIN') }}
          </router-link>
          <router-link
            v-if="showSignupLink"
            to="/app/auth/signup"
            class="rounded-xl bg-[#D97757] px-4 py-2 text-sm font-medium text-white shadow-sm transition-all hover:bg-[#C4654A] hover:shadow-md"
          >
            {{ t('LANDING.HERO.CTA_SIGNUP') }}
          </router-link>
        </div>
      </div>
    </nav>

    <main>
      <!-- Hero -->
      <section
        class="relative mx-auto flex max-w-4xl flex-col items-center px-6 pb-16 pt-24 text-center sm:pb-24 sm:pt-36"
      >
        <h1
          class="max-w-3xl font-['Lora',serif] text-4xl font-semibold leading-tight tracking-tight text-[#3F3E3A] dark:text-n-slate-12 sm:text-6xl sm:leading-tight"
        >
          {{ t('LANDING.HERO.TITLE') }}
          <span
            class="bg-gradient-to-r from-[#D97757] to-[#E8956F] bg-clip-text text-transparent"
          >
            {{ t('LANDING.HERO.TITLE_ACCENT') }}
          </span>
        </h1>
        <p
          class="mt-6 max-w-2xl text-lg leading-relaxed text-[#767470] dark:text-n-slate-11"
        >
          {{ t('LANDING.HERO.SUBTITLE') }}
        </p>
        <div class="mt-10 flex flex-wrap items-center justify-center gap-4">
          <router-link
            v-if="showSignupLink"
            to="/app/auth/signup"
            class="rounded-xl bg-[#D97757] px-7 py-3.5 text-base font-medium text-white shadow-lg shadow-[#D97757]/25 transition-all hover:bg-[#C4654A] hover:shadow-xl hover:shadow-[#D97757]/30"
          >
            {{ t('LANDING.HERO.CTA_SIGNUP') }}
          </router-link>
          <router-link
            to="/app/login"
            class="rounded-xl border border-[#E6E4DD] bg-white px-7 py-3.5 text-base font-medium text-[#3F3E3A] shadow-sm transition-all hover:shadow-md dark:border-n-strong dark:bg-n-solid-2 dark:text-n-slate-12"
          >
            {{ t('LANDING.HERO.CTA_LOGIN') }}
          </router-link>
        </div>
      </section>

      <!-- Stats -->
      <section class="mx-auto max-w-4xl px-6 pb-16 sm:pb-24">
        <div
          class="grid grid-cols-3 divide-x divide-[#E6E4DD] rounded-2xl border border-[#E6E4DD] bg-white/70 px-2 py-8 shadow-[0_2px_16px_rgba(0,0,0,0.04)] backdrop-blur-sm dark:divide-n-strong dark:border-n-strong dark:bg-n-solid-2/70 sm:py-10"
        >
          <div
            v-for="stat in stats"
            :key="stat.valueKey"
            class="flex flex-col items-center gap-1 px-4"
          >
            <span
              class="font-['Lora',serif] text-2xl font-semibold text-[#D97757] sm:text-3xl"
            >
              <!-- eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys -->
              {{ t(stat.valueKey) }}
            </span>
            <span
              class="text-center text-xs text-[#767470] dark:text-n-slate-11 sm:text-sm"
            >
              <!-- eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys -->
              {{ t(stat.descKey) }}
            </span>
          </div>
        </div>
      </section>

      <!-- Features -->
      <section class="mx-auto max-w-6xl px-6 pb-16 sm:pb-24">
        <div class="mb-12 text-center">
          <h2
            class="font-['Lora',serif] text-3xl font-semibold text-[#3F3E3A] dark:text-n-slate-12 sm:text-4xl"
          >
            {{ t('LANDING.FEATURES.TITLE') }}
          </h2>
          <p
            class="mt-4 text-base text-[#767470] dark:text-n-slate-11 sm:text-lg"
          >
            {{ t('LANDING.FEATURES.SUBTITLE') }}
          </p>
        </div>
        <div class="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          <div
            v-for="feature in features"
            :key="feature.titleKey"
            class="group flex flex-col rounded-2xl border border-[#E6E4DD] bg-white p-7 shadow-[0_2px_16px_rgba(0,0,0,0.04)] transition-all duration-300 hover:shadow-[0_8px_30px_rgba(0,0,0,0.08)] dark:border-n-strong dark:bg-n-solid-2"
          >
            <div
              class="flex size-12 items-center justify-center rounded-xl transition-transform duration-300 group-hover:scale-110"
              :class="feature.color"
            >
              <Icon
                :icon="feature.icon"
                class="size-6"
                :class="feature.iconColor"
              />
            </div>
            <h3
              class="mt-5 text-base font-semibold text-[#3F3E3A] dark:text-n-slate-12"
            >
              <!-- eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys -->
              {{ t(feature.titleKey) }}
            </h3>
            <p
              class="mt-2 text-sm leading-relaxed text-[#767470] dark:text-n-slate-11"
            >
              <!-- eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys -->
              {{ t(feature.descKey) }}
            </p>
          </div>
        </div>
      </section>

      <!-- How it works -->
      <section class="mx-auto max-w-5xl px-6 pb-16 sm:pb-24">
        <div class="mb-12 text-center">
          <h2
            class="font-['Lora',serif] text-3xl font-semibold text-[#3F3E3A] dark:text-n-slate-12 sm:text-4xl"
          >
            {{ t('LANDING.HOW_IT_WORKS.TITLE') }}
          </h2>
          <p
            class="mt-4 text-base text-[#767470] dark:text-n-slate-11 sm:text-lg"
          >
            {{ t('LANDING.HOW_IT_WORKS.SUBTITLE') }}
          </p>
        </div>
        <div class="relative grid gap-8 sm:grid-cols-3">
          <!-- Connector line (desktop only) -->
          <div
            class="absolute left-[16.66%] right-[16.66%] top-10 hidden h-px bg-gradient-to-r from-[#E6E4DD] via-[#D97757]/30 to-[#E6E4DD] dark:from-n-strong dark:via-[#D97757]/20 dark:to-n-strong sm:block"
          />
          <div
            v-for="step in steps"
            :key="step.number"
            class="relative flex flex-col items-center text-center"
          >
            <div
              class="relative z-10 flex size-20 items-center justify-center rounded-2xl border border-[#E6E4DD] bg-white shadow-[0_2px_16px_rgba(0,0,0,0.04)] dark:border-n-strong dark:bg-n-solid-2"
            >
              <Icon :icon="step.icon" class="size-8 text-[#D97757]" />
            </div>
            <span
              class="mt-1 font-['Lora',serif] text-xs font-medium text-[#D97757]/60"
            >
              {{ step.number }}
            </span>
            <h3
              class="mt-3 text-base font-semibold text-[#3F3E3A] dark:text-n-slate-12"
            >
              <!-- eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys -->
              {{ t(step.titleKey) }}
            </h3>
            <p
              class="mt-2 max-w-xs text-sm leading-relaxed text-[#767470] dark:text-n-slate-11"
            >
              <!-- eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys -->
              {{ t(step.descKey) }}
            </p>
          </div>
        </div>
      </section>

      <!-- Final CTA -->
      <section class="px-6 pb-16 sm:pb-24">
        <div
          class="mx-auto max-w-4xl overflow-hidden rounded-3xl bg-gradient-to-br from-[#D97757] to-[#C4654A] px-8 py-16 text-center shadow-xl sm:px-16 sm:py-20"
        >
          <h2
            class="font-['Lora',serif] text-2xl font-semibold leading-tight text-white sm:text-4xl"
          >
            {{ t('LANDING.CTA.TITLE') }}
          </h2>
          <p class="mx-auto mt-4 max-w-lg text-base text-white/80">
            {{ t('LANDING.CTA.SUBTITLE') }}
          </p>
          <router-link
            v-if="showSignupLink"
            to="/app/auth/signup"
            class="mt-8 inline-block rounded-xl bg-white px-8 py-3.5 text-base font-semibold text-[#D97757] shadow-lg transition-all hover:shadow-xl"
          >
            {{ t('LANDING.CTA.BUTTON') }}
          </router-link>
          <router-link
            v-else
            to="/app/login"
            class="mt-8 inline-block rounded-xl bg-white px-8 py-3.5 text-base font-semibold text-[#D97757] shadow-lg transition-all hover:shadow-xl"
          >
            {{ t('LANDING.HERO.CTA_LOGIN') }}
          </router-link>
        </div>
      </section>
    </main>

    <!-- Footer -->
    <footer class="border-t border-[#E6E4DD] px-6 py-8 dark:border-n-strong">
      <p class="text-center text-sm text-[#767470] dark:text-n-slate-10">
        {{
          replaceInstallationName(
            t('LANDING.FOOTER.POWERED_BY', {
              installationName: globalConfig.installationName,
            })
          )
        }}
      </p>
    </footer>
  </div>
</template>
