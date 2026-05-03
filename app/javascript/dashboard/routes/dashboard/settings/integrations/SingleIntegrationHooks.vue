<script setup>
import { computed, defineProps, defineEmits } from 'vue';
import { useIntegrationHook } from 'dashboard/composables/useIntegrationHook';
import { useBranding } from 'shared/composables/useBranding';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  integrationId: {
    type: String,
    required: true,
  },
});

defineEmits(['add', 'delete']);

const { integration, hasConnectedHooks } = useIntegrationHook(
  props.integrationId
);

const { replaceInstallationName } = useBranding();

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
  if (integration.value.logo) return buildLogoPath(integration.value.logo);
  return `/dashboard/images/integrations/${props.integrationId}.png`;
});

const logoDarkPath = computed(() => {
  if (integration.value.logo_dark)
    return buildLogoPath(integration.value.logo_dark);
  if (integration.value.logo)
    return buildLogoPath(buildDarkLogoFallback(integration.value.logo));
  return `/dashboard/images/integrations/${props.integrationId}-dark.png`;
});
</script>

<template>
  <div
    class="outline outline-n-border-glass-soft outline-1 bg-n-card rounded-xl flex-grow overflow-auto p-4"
  >
    <div class="flex items-center justify-center">
      <div class="flex h-16 w-16 items-center justify-center">
        <img
          :src="logoPath"
          class="max-w-full rounded-md border border-n-border-glass-soft shadow-sm block dark:hidden bg-n-alpha-3 dark:bg-n-alpha-2"
        />
        <img
          :src="logoDarkPath"
          class="max-w-full rounded-md border border-n-border-glass-soft shadow-sm hidden dark:block bg-n-alpha-3 dark:bg-n-alpha-2"
        />
      </div>
      <div class="flex flex-col justify-center m-0 mx-4 flex-1">
        <h3 class="mb-1 text-heading-1 text-n-text-display">
          {{ integration.name }}
        </h3>
        <p class="text-n-text-body text-body-main">
          {{ replaceInstallationName(integration.description) }}
        </p>
      </div>
      <div class="flex justify-center items-center mb-0 w-[15%]">
        <div v-if="hasConnectedHooks">
          <div @click="$emit('delete', integration.hooks[0])">
            <Button
              ruby
              faded
              :label="$t('INTEGRATION_APPS.DISCONNECT.BUTTON_TEXT')"
            />
          </div>
        </div>
        <div v-else>
          <Button
            blue
            faded
            :label="$t('INTEGRATION_APPS.CONNECT.BUTTON_TEXT')"
            @click="$emit('add')"
          />
        </div>
      </div>
    </div>
  </div>
</template>
