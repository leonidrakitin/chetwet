<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SectionLayout from './SectionLayout.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const { t, locale } = useI18n();

const BUSINESS_TYPES = [
  {
    id: 'support',
    labelKey: 'ONBOARDING_WIZARD.USE_CASE_SUPPORT',
    icon: 'i-lucide-headphones',
  },
  {
    id: 'sales',
    labelKey: 'ONBOARDING_WIZARD.USE_CASE_SALES',
    icon: 'i-lucide-trending-up',
  },
  {
    id: 'feedback',
    labelKey: 'ONBOARDING_WIZARD.USE_CASE_FEEDBACK',
    icon: 'i-lucide-message-square',
  },
  {
    id: 'internal',
    labelKey: 'ONBOARDING_WIZARD.USE_CASE_INTERNAL',
    icon: 'i-lucide-users',
  },
  {
    id: 'ecommerce',
    labelKey: 'ONBOARDING_WIZARD.USE_CASE_ECOMMERCE',
    icon: 'i-lucide-shopping-bag',
  },
  {
    id: 'other',
    labelKey: 'ONBOARDING_WIZARD.USE_CASE_OTHER',
    icon: 'i-lucide-layers',
  },
];

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

const businessType = ref('');
const description = ref('');
const isUpdating = ref(false);

const accountId = computed(() => store.getters.getCurrentAccountId);
const currentAccount = useMapGetter('accounts/getAccount');

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

const characterCount = computed(() => description.value.length);
const maxCharacters = 200;
const isOverLimit = computed(() => characterCount.value > maxCharacters);

function initializeFromAccount() {
  const account = currentAccount.value(accountId.value);
  if (account?.settings?.business_context) {
    businessType.value = account.settings.business_context.business_type || '';
    description.value = account.settings.business_context.description || '';
  }
}

onMounted(() => {
  initializeFromAccount();
});

async function updateBusinessContext() {
  if (isOverLimit.value) return;

  isUpdating.value = true;
  try {
    await store.dispatch('accounts/update', {
      id: accountId.value,
      business_context: {
        business_type: businessType.value,
        description: description.value,
      },
    });
    useAlert(t('GENERAL_SETTINGS.BUSINESS_CONTEXT.SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.BUSINESS_CONTEXT.ERROR'));
  } finally {
    isUpdating.value = false;
  }
}
</script>

<template>
  <SectionLayout
    :title="$t('GENERAL_SETTINGS.BUSINESS_CONTEXT.TITLE')"
    :description="$t('GENERAL_SETTINGS.BUSINESS_CONTEXT.DESCRIPTION')"
    class="mt-6"
  >
    <div class="flex flex-col gap-4">
      <WithLabel
        name="business-type"
        :label="$t('GENERAL_SETTINGS.BUSINESS_CONTEXT.BUSINESS_TYPE_LABEL')"
      >
        <select
          v-model="businessType"
          class="appearance-none rounded-lg border border-n-border-glass-soft bg-n-glass-soft py-2 px-3 text-sm w-full text-n-text-display"
        >
          <option value="" disabled>
            {{
              $t('GENERAL_SETTINGS.BUSINESS_CONTEXT.BUSINESS_TYPE_PLACEHOLDER')
            }}
          </option>
          <option
            v-for="type in BUSINESS_TYPES"
            :key="type.id"
            :value="type.id"
          >
            {{ $t(type.labelKey) }}
          </option>
        </select>
      </WithLabel>

      <div>
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{ $t('GENERAL_SETTINGS.BUSINESS_CONTEXT.DESCRIPTION_LABEL') }}
        </label>
        <textarea
          v-model="description"
          rows="3"
          class="w-full px-3 py-2 text-sm border border-n-border-glass-soft rounded-lg bg-n-glass-soft resize-none focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand"
          :class="{ 'border-red-500': isOverLimit }"
          :placeholder="
            $t('GENERAL_SETTINGS.BUSINESS_CONTEXT.DESCRIPTION_PLACEHOLDER')
          "
          maxlength="200"
        />
        <div class="flex items-center justify-between mt-1">
          <p v-if="exampleText" class="text-xs text-n-slate-10 italic">
            {{ $t('ONBOARDING_WIZARD.EXAMPLE_LABEL') }}: {{ exampleText }}
          </p>
          <p
            class="text-xs ml-auto"
            :class="isOverLimit ? 'text-red-500' : 'text-n-slate-10'"
          >
            {{ characterCount }}/{{ maxCharacters }}
          </p>
        </div>
      </div>

      <div>
        <NextButton
          blue
          :is-loading="isUpdating"
          :disabled="isOverLimit"
          @click="updateBusinessContext"
        >
          {{ $t('GENERAL_SETTINGS.BUSINESS_CONTEXT.UPDATE_BUTTON') }}
        </NextButton>
      </div>
    </div>
  </SectionLayout>
</template>
