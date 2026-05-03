<script setup>
import { computed } from 'vue';
import { useStoreGetters } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { useBranding } from 'shared/composables/useBranding';

import Button from 'dashboard/components-next/button/Button.vue';
import Label from 'dashboard/components-next/label/Label.vue';

const props = defineProps({
  id: {
    type: [String, Number],
    required: true,
  },
  logo: {
    type: String,
    default: '',
  },
  logoDark: {
    type: String,
    default: '',
  },
  name: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
  enabled: {
    type: Boolean,
    default: false,
  },
});

const getters = useStoreGetters();
const accountId = getters.getCurrentAccountId;

const { t } = useI18n();
const { replaceInstallationName } = useBranding();

const integrationStatus = computed(() =>
  props.enabled
    ? t('INTEGRATION_APPS.STATUS.ENABLED')
    : t('INTEGRATION_APPS.STATUS.DISABLED')
);

const integrationStatusColor = computed(() =>
  props.enabled ? 'teal' : 'slate'
);

const buildLogoPath = logoValue => {
  if (!logoValue) return '';
  if (
    logoValue.startsWith('http') ||
    logoValue.startsWith('data:') ||
    logoValue.startsWith('/')
  ) {
    return logoValue;
  }
  return `/dashboard/images/integrations/${logoValue}`;
};

const buildDarkLogoFallback = logoValue => {
  const match = logoValue.match(/^(.*)(\.[^.]+)$/);
  if (match) {
    return `${match[1]}-dark${match[2]}`;
  }
  return `${logoValue}-dark`;
};

const logoPath = computed(() => {
  if (props.logo) return buildLogoPath(props.logo);
  return `/dashboard/images/integrations/${props.id}.png`;
});

const logoDarkPath = computed(() => {
  if (props.logoDark) return buildLogoPath(props.logoDark);
  if (props.logo) return buildLogoPath(buildDarkLogoFallback(props.logo));
  return `/dashboard/images/integrations/${props.id}-dark.png`;
});

const actionURL = computed(() =>
  frontendURL(`accounts/${accountId.value}/settings/integrations/${props.id}`)
);
</script>

<template>
  <div
    class="flex flex-col flex-1 p-4 m-px outline outline-n-border-glass-soft outline-1 bg-n-card rounded-xl"
  >
    <div class="flex items-start justify-between">
      <div class="flex h-12 w-12 mb-2">
        <img
          :src="logoPath"
          class="max-w-full rounded-md border border-n-border-glass-soft shadow-sm block dark:hidden bg-n-alpha-3 dark:bg-n-alpha-2"
        />
        <img
          :src="logoDarkPath"
          class="max-w-full rounded-md border border-n-border-glass-soft shadow-sm hidden dark:block bg-n-alpha-3 dark:bg-n-alpha-2"
        />
      </div>
      <Label
        :label="integrationStatus"
        :color="integrationStatusColor"
        compact
      />
    </div>
    <div class="flex flex-col m-0 flex-1">
      <div
        class="font-medium mb-2 text-n-text-display flex justify-between items-center"
      >
        <span class="text-heading-3 text-n-text-display">{{ name }}</span>
        <router-link :to="actionURL">
          <Button
            :label="$t('INTEGRATION_APPS.CONFIGURE')"
            icon="i-woot-settings"
            link
            xs
          />
        </router-link>
      </div>
      <p class="text-n-text-body text-body-main">
        {{ replaceInstallationName(description) }}
      </p>
    </div>
  </div>
</template>
