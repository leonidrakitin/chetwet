<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  initialName: { type: String, default: '' },
});

const emit = defineEmits(['next', 'update']);
const store = useStore();
const { t } = useI18n();

const displayName = ref(props.initialName);

const globalConfig = computed(() => store.getters['globalConfig/get']);

watch(displayName, val => {
  emit('update', { displayName: val });
});

function proceed() {
  emit('next', { displayName: displayName.value.trim() });
}
</script>

<template>
  <div class="flex flex-col items-center text-center px-2">
    <div
      class="flex items-center justify-center w-16 h-16 rounded-2xl bg-n-brand/10 mb-6"
    >
      <Icon icon="i-lucide-hand-metal" class="size-8 text-n-brand" />
    </div>
    <h1 class="text-2xl font-bold text-n-slate-12 mb-2">
      {{
        t('ONBOARDING_WIZARD.WELCOME_TITLE', {
          installationName: globalConfig.installationName,
        })
      }}
    </h1>
    <p class="text-sm text-n-slate-10 mb-8">
      {{ t('ONBOARDING_WIZARD.WELCOME_SUBTITLE') }}
    </p>
    <div class="w-full max-w-xs">
      <NextInput
        v-model="displayName"
        :label="t('ONBOARDING_WIZARD.DISPLAY_NAME_LABEL')"
        :placeholder="t('ONBOARDING_WIZARD.DISPLAY_NAME_PLACEHOLDER')"
        autofocus
        @enter="proceed"
      />
    </div>
  </div>
</template>
