<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  initialBusinessType: { type: String, default: '' },
  initialDescription: { type: String, default: '' },
});

const { t, locale } = useI18n();

const businessType = ref(props.initialBusinessType);
const description = ref(props.initialDescription);

const BUSINESS_TYPE_LABELS = {
  support: 'ONBOARDING_WIZARD.USE_CASE_SUPPORT',
  sales: 'ONBOARDING_WIZARD.USE_CASE_SALES',
  feedback: 'ONBOARDING_WIZARD.USE_CASE_FEEDBACK',
  internal: 'ONBOARDING_WIZARD.USE_CASE_INTERNAL',
  ecommerce: 'ONBOARDING_WIZARD.USE_CASE_ECOMMERCE',
  other: 'ONBOARDING_WIZARD.USE_CASE_OTHER',
};

const BUSINESS_TYPE_ICONS = {
  support: 'i-lucide-headphones',
  sales: 'i-lucide-trending-up',
  feedback: 'i-lucide-message-square',
  internal: 'i-lucide-users',
  ecommerce: 'i-lucide-shopping-bag',
  other: 'i-lucide-layers',
};

const EXAMPLES = {
  support: {
    en: 'We provide 24/7 technical support for our SaaS project management platform.',
    ru: 'Мы предоставляем круглосуточную техподдержку для SaaS-платформы управления проектами.',
  },
  sales: {
    en: 'We are a B2B sales platform helping companies find and close leads.',
    ru: 'Мы B2B платформа продаж, помогающая компаниям находить и закрывать сделки.',
  },
  feedback: {
    en: 'We collect and analyze customer feedback for product improvement.',
    ru: 'Мы собираем и анализируем отзывы клиентов для улучшения продукта.',
  },
  internal: {
    en: 'We use this for internal team communication and coordination.',
    ru: 'Мы используем это для внутренней коммуникации и координации команды.',
  },
  ecommerce: {
    en: 'We are an online store selling handmade jewelry worldwide.',
    ru: 'Мы интернет-магазин авторских украшений с доставкой по всему миру.',
  },
  other: {
    en: 'We help businesses automate their customer communication.',
    ru: 'Мы помогаем бизнесу автоматизировать общение с клиентами.',
  },
};

const currentLocale = computed(() => {
  return locale.value?.startsWith('ru') ? 'ru' : 'en';
});

const exampleText = computed(() => {
  if (!businessType.value) return '';
  return (
    EXAMPLES[businessType.value]?.[currentLocale.value] ||
    EXAMPLES[businessType.value]?.en ||
    ''
  );
});

const businessTypeLabel = computed(() => {
  if (!businessType.value) return '';
  return t(BUSINESS_TYPE_LABELS[businessType.value]);
});

const businessTypeIcon = computed(() => {
  return BUSINESS_TYPE_ICONS[businessType.value] || 'i-lucide-layers';
});

const characterCount = computed(() => description.value.length);
const maxCharacters = 200;
const isOverLimit = computed(() => characterCount.value > maxCharacters);
</script>

<template>
  <div class="flex flex-col items-center text-center px-2">
    <h1 class="text-2xl font-bold text-n-slate-12 mb-2">
      {{ t('ONBOARDING_WIZARD.BUSINESS_CONTEXT_TITLE') }}
    </h1>
    <p class="text-sm text-n-slate-10 mb-6">
      {{ t('ONBOARDING_WIZARD.BUSINESS_CONTEXT_SUBTITLE') }}
    </p>

    <div
      class="w-full bg-n-brand/5 dark:bg-n-brand/10 rounded-xl p-4 mb-6 text-left"
    >
      <div class="flex items-start gap-3">
        <Icon
          icon="i-lucide-info"
          class="size-5 text-n-brand mt-0.5 flex-shrink-0"
        />
        <div>
          <p class="text-sm font-medium text-n-slate-12 mb-1">
            {{ t('ONBOARDING_WIZARD.BUSINESS_CONTEXT_WARNING_TITLE') }}
          </p>
          <p class="text-xs text-n-slate-11">
            {{ t('ONBOARDING_WIZARD.BUSINESS_CONTEXT_WARNING_TEXT') }}
          </p>
        </div>
      </div>
    </div>

    <div class="w-full mb-6">
      <label class="block text-sm font-medium text-n-slate-12 mb-2 text-left">
        {{ t('ONBOARDING_WIZARD.BUSINESS_TYPE_LABEL') }}
      </label>
      <div
        class="flex items-center gap-3 p-3 bg-n-surface-1 rounded-lg border border-n-weak"
      >
        <Icon :icon="businessTypeIcon" class="size-5 text-n-brand" />
        <span class="text-sm text-n-slate-12">{{ businessTypeLabel }}</span>
      </div>
    </div>

    <div class="w-full">
      <label class="block text-sm font-medium text-n-slate-12 mb-2 text-left">
        {{ t('ONBOARDING_WIZARD.BUSINESS_DESCRIPTION_LABEL') }}
      </label>
      <textarea
        v-model="description"
        rows="3"
        class="w-full px-3 py-2 text-sm border border-n-weak rounded-lg bg-n-surface-1 resize-none focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand"
        :class="{ 'border-red-500': isOverLimit }"
        :placeholder="t('ONBOARDING_WIZARD.BUSINESS_DESCRIPTION_PLACEHOLDER')"
        maxlength="200"
      />
      <div class="flex items-center justify-between mt-1">
        <p v-if="exampleText" class="text-xs text-n-slate-10 italic">
          {{ t('ONBOARDING_WIZARD.EXAMPLE_LABEL') }}: {{ exampleText }}
        </p>
        <p
          class="text-xs ml-auto"
          :class="isOverLimit ? 'text-red-500' : 'text-n-slate-10'"
        >
          {{ characterCount }}/{{ maxCharacters }}
        </p>
      </div>
    </div>
  </div>
</template>
