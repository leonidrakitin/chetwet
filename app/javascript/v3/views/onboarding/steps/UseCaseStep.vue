<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  initialUseCase: { type: String, default: '' },
});

const emit = defineEmits(['next']);
const { t } = useI18n();

const selected = ref(props.initialUseCase);

const USE_CASES = [
  {
    id: 'support',
    icon: 'i-lucide-headphones',
    labelKey: 'ONBOARDING_WIZARD.USE_CASE_SUPPORT',
  },
  {
    id: 'sales',
    icon: 'i-lucide-trending-up',
    labelKey: 'ONBOARDING_WIZARD.USE_CASE_SALES',
  },
  {
    id: 'feedback',
    icon: 'i-lucide-message-square',
    labelKey: 'ONBOARDING_WIZARD.USE_CASE_FEEDBACK',
  },
  {
    id: 'internal',
    icon: 'i-lucide-users',
    labelKey: 'ONBOARDING_WIZARD.USE_CASE_INTERNAL',
  },
  {
    id: 'ecommerce',
    icon: 'i-lucide-shopping-bag',
    labelKey: 'ONBOARDING_WIZARD.USE_CASE_ECOMMERCE',
  },
  {
    id: 'other',
    icon: 'i-lucide-layers',
    labelKey: 'ONBOARDING_WIZARD.USE_CASE_OTHER',
  },
];

function select(id) {
  selected.value = id;
  emit('next', { useCase: id });
}
</script>

<template>
  <div class="flex flex-col items-center text-center px-2">
    <h1 class="text-2xl font-bold text-n-slate-12 mb-2">
      {{ t('ONBOARDING_WIZARD.USE_CASE_TITLE') }}
    </h1>
    <p class="text-sm text-n-slate-10 mb-8">
      {{ t('ONBOARDING_WIZARD.USE_CASE_SUBTITLE') }}
    </p>
    <div class="grid grid-cols-2 gap-3 w-full">
      <button
        v-for="uc in USE_CASES"
        :key="uc.id"
        class="flex flex-col items-center gap-2 p-4 rounded-xl text-sm font-medium transition-all outline outline-1 -outline-offset-1"
        :class="
          selected === uc.id
            ? 'bg-n-brand/10 text-n-brand outline-n-brand/30'
            : 'bg-white dark:bg-n-solid-3 text-n-slate-11 outline-n-container hover:outline-n-brand/30 hover:bg-n-alpha-1'
        "
        @click="select(uc.id)"
      >
        <Icon :icon="uc.icon" class="size-6" />
        <span>{{ t(uc.labelKey) }}</span>
      </button>
    </div>
  </div>
</template>
