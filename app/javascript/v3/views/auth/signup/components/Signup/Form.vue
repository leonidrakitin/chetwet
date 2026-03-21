<script setup>
import { ref, computed, reactive } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, email } from '@vuelidate/validators';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useToast } from 'dashboard/composables';
import VueHcaptcha from '@hcaptcha/vue3-hcaptcha';
import FormInput from '../../../../../components/Form/Input.vue';
import FormCheckBox from '../../../../../components/Form/CheckBox.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SimpleDivider from '../../../../../components/Divider/SimpleDivider.vue';
import PasswordRequirements from './PasswordRequirements.vue';
import { isValidPassword } from 'shared/helpers/Validators';
import GoogleOAuthButton from '../../../../../components/GoogleOauth/Button.vue';
import VkIdOAuthButton from '../../../../../components/VkIdOauth/Button.vue';
import YandexOAuthButton from '../../../../../components/YandexOauth/Button.vue';
import { register } from '../../../../../api/auth';
import * as CompanyEmailValidator from 'company-email-validator';

const MIN_PASSWORD_LENGTH = 6;

const store = useStore();
const { t } = useI18n();

const hCaptcha = ref(null);
const isPasswordFocused = ref(false);
const isSignupInProgress = ref(false);
const consentPersonalData = ref(false);
const consentMarketing = ref(false);
const showConsentError = ref(false);

const credentials = reactive({
  email: '',
  password: '',
  hCaptchaClientResponse: '',
});

const rules = {
  credentials: {
    email: {
      required,
      email,
      businessEmailValidator(value) {
        return CompanyEmailValidator.isCompanyEmail(value);
      },
    },
    password: {
      required,
      isValidPassword,
      minLength: minLength(MIN_PASSWORD_LENGTH),
    },
  },
};

const v$ = useVuelidate(rules, { credentials });

const globalConfig = computed(() => store.getters['globalConfig/get']);

const termsLink = computed(() =>
  t('REGISTER.TERMS_ACCEPT')
    .replace('https://www.chatwoot.com/terms', globalConfig.value.termsURL)
    .replace(
      'https://www.chatwoot.com/privacy-policy',
      globalConfig.value.privacyURL
    )
);

const allowedLoginMethods = computed(
  () => window.chatwootConfig.allowedLoginMethods || ['email']
);

const showGoogleOAuth = computed(
  () =>
    allowedLoginMethods.value.includes('google_oauth') &&
    Boolean(window.chatwootConfig.googleOAuthClientId)
);

const showVkIdOAuth = computed(
  () =>
    allowedLoginMethods.value.includes('vk_id_oauth') &&
    Boolean(window.chatwootConfig.vkIdClientId)
);

const showYandexOAuth = computed(
  () =>
    allowedLoginMethods.value.includes('yandex_oauth') &&
    Boolean(window.chatwootConfig.yandexOAuthClientId)
);

const hasSocialLogin = computed(
  () => showGoogleOAuth.value || showVkIdOAuth.value || showYandexOAuth.value
);

const isFormValid = computed(() => !v$.value.$invalid);
const isConsentValid = computed(() => consentPersonalData.value);

const performRegistration = async () => {
  isSignupInProgress.value = true;
  try {
    await register(credentials);
    window.location = '/app/onboarding/wizard';
  } catch (error) {
    const errorMessage = error?.message || t('REGISTER.API.ERROR_MESSAGE');
    if (globalConfig.value.hCaptchaSiteKey) {
      hCaptcha.value.reset();
      credentials.hCaptchaClientResponse = '';
    }
    useToast.error(errorMessage);
  } finally {
    isSignupInProgress.value = false;
  }
};

const submit = () => {
  if (isSignupInProgress.value) return;

  if (!isConsentValid.value) {
    showConsentError.value = true;
    useToast.warning(t('REGISTER.CONSENT.REQUIRED'));
    return;
  }
  showConsentError.value = false;

  v$.value.$touch();
  if (v$.value.$invalid) return;
  isSignupInProgress.value = true;
  if (globalConfig.value.hCaptchaSiteKey) {
    hCaptcha.value.execute();
  } else {
    performRegistration();
  }
};

const onRecaptchaVerified = token => {
  credentials.hCaptchaClientResponse = token;
  performRegistration();
};

const onCaptchaError = () => {
  isSignupInProgress.value = false;
  credentials.hCaptchaClientResponse = '';
  hCaptcha.value.reset();
};

const handleConsentPersonalData = (_value, checked) => {
  consentPersonalData.value = checked;
  if (checked) showConsentError.value = false;
};

const handleConsentMarketing = (_value, checked) => {
  consentMarketing.value = checked;
};
</script>

<template>
  <div class="flex-1">
    <!-- Email Signup Form -->
    <form class="space-y-3" @submit.prevent="submit">
      <FormInput
        v-model="credentials.email"
        type="email"
        name="email_address"
        :class="{ error: v$.credentials.email.$error }"
        :label="$t('REGISTER.EMAIL.LABEL')"
        :placeholder="$t('REGISTER.EMAIL.PLACEHOLDER')"
        :has-error="v$.credentials.email.$error"
        :error-message="$t('REGISTER.EMAIL.ERROR')"
        @blur="v$.credentials.email.$touch"
      />
      <div class="relative">
        <FormInput
          v-model="credentials.password"
          type="password"
          name="password"
          :class="{ error: v$.credentials.password.$error }"
          :label="$t('LOGIN.PASSWORD.LABEL')"
          :placeholder="$t('SET_NEW_PASSWORD.PASSWORD.PLACEHOLDER')"
          :has-error="v$.credentials.password.$error"
          @focus="isPasswordFocused = true"
          @blur="
            isPasswordFocused = false;
            v$.credentials.password.$touch();
          "
        />
        <Transition
          enter-active-class="transition duration-200 ease-out origin-left"
          enter-from-class="opacity-0 scale-90 translate-x-1"
          enter-to-class="opacity-100 scale-100 translate-x-0"
          leave-active-class="transition duration-150 ease-in origin-left"
          leave-from-class="opacity-100 scale-100 translate-x-0"
          leave-to-class="opacity-0 scale-90 translate-x-1"
        >
          <PasswordRequirements
            v-if="isPasswordFocused"
            :password="credentials.password"
          />
        </Transition>
      </div>

      <!-- Consent Checkboxes -->
      <div
        class="space-y-3 pt-3 pb-1"
        :class="{
          'rounded-lg ring-1 ring-n-ruby-9 p-3': showConsentError,
        }"
      >
        <label class="flex items-start gap-2 cursor-pointer">
          <FormCheckBox
            :is-checked="consentPersonalData"
            value="personal_data"
            @update="handleConsentPersonalData"
          />
          <span class="text-sm text-n-slate-11 leading-snug select-none">
            {{ $t('REGISTER.CONSENT.PERSONAL_DATA') }}
            <span class="text-n-ruby-9">*</span>
          </span>
        </label>
        <label class="flex items-start gap-2 cursor-pointer">
          <FormCheckBox
            :is-checked="consentMarketing"
            value="marketing"
            @update="handleConsentMarketing"
          />
          <span class="text-sm text-n-slate-11 leading-snug select-none">
            {{ $t('REGISTER.CONSENT.MARKETING') }}
          </span>
        </label>
      </div>

      <VueHcaptcha
        v-if="globalConfig.hCaptchaSiteKey"
        ref="hCaptcha"
        size="invisible"
        :sitekey="globalConfig.hCaptchaSiteKey"
        @verify="onRecaptchaVerified"
        @error="onCaptchaError"
        @expired="onCaptchaError"
        @challenge-expired="onCaptchaError"
        @closed="onCaptchaError"
      />
      <NextButton
        lg
        type="submit"
        data-testid="submit_button"
        class="w-full font-medium"
        :label="$t('REGISTER.SUBMIT')"
        :disabled="isSignupInProgress || !isFormValid || !isConsentValid"
        :is-loading="isSignupInProgress"
      />
    </form>

    <!-- Social Login Buttons -->
    <div v-if="hasSocialLogin" class="flex flex-col gap-3 mt-4">
      <SimpleDivider :label="$t('REGISTER.EMAIL_SECTION_TITLE')" class="mb-1" />
      <GoogleOAuthButton v-if="showGoogleOAuth">
        {{ $t('REGISTER.OAUTH.GOOGLE_SIGNUP') }}
      </GoogleOAuthButton>
      <VkIdOAuthButton v-if="showVkIdOAuth" />
      <YandexOAuthButton v-if="showYandexOAuth" />
    </div>

    <p
      class="text-xs mt-4 mb-0 text-n-slate-10 [&>a]:text-n-blue-10 [&>a]:font-medium [&>a]:hover:text-n-blue-11"
      v-html="termsLink"
    />
  </div>
</template>
