<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  initialChannels: { type: Array, default: () => [] },
});

const emit = defineEmits(['update']);
const { t } = useI18n();

const selected = ref([...props.initialChannels]);

const CHANNELS = [
  {
    id: 'whatsapp',
    icon: 'i-lucide-message-circle',
    labelKey: 'ONBOARDING_WIZARD.CHANNEL_WHATSAPP',
  },
  {
    id: 'telegram',
    icon: 'i-lucide-send',
    labelKey: 'ONBOARDING_WIZARD.CHANNEL_TELEGRAM',
  },
  {
    id: 'vk',
    icon: 'i-lucide-messages-square',
    labelKey: 'ONBOARDING_WIZARD.CHANNEL_VK',
  },
  {
    id: 'email',
    icon: 'i-lucide-mail',
    labelKey: 'ONBOARDING_WIZARD.CHANNEL_EMAIL',
  },
  {
    id: 'website',
    icon: 'i-lucide-globe',
    labelKey: 'ONBOARDING_WIZARD.CHANNEL_WEBSITE',
  },
];

function toggle(id) {
  const idx = selected.value.indexOf(id);
  if (idx >= 0) {
    selected.value.splice(idx, 1);
  } else {
    selected.value.push(id);
  }
  emit('update', { channels: [...selected.value] });
}
</script>

<template>
  <div class="flex flex-col items-center text-center px-2">
    <h1 class="text-2xl font-bold text-n-slate-12 mb-2">
      {{ t('ONBOARDING_WIZARD.CHANNELS_TITLE') }}
    </h1>
    <p class="text-sm text-n-slate-10 mb-8">
      {{ t('ONBOARDING_WIZARD.CHANNELS_SUBTITLE') }}
    </p>
    <div class="flex flex-wrap justify-center gap-3 w-full">
      <button
        v-for="ch in CHANNELS"
        :key="ch.id"
        class="flex items-center gap-2.5 px-4 py-3 rounded-xl text-sm font-medium transition-all outline outline-1 -outline-offset-1"
        :class="
          selected.includes(ch.id)
            ? 'bg-n-brand/10 text-n-brand outline-n-brand/30'
            : 'bg-white dark:bg-n-solid-3 text-n-slate-11 outline-n-container hover:outline-n-brand/30 hover:bg-n-alpha-1'
        "
        @click="toggle(ch.id)"
      >
        <Icon :icon="ch.icon" class="size-5" />
        <span>{{ t(ch.labelKey) }}</span>
      </button>
    </div>
  </div>
</template>
