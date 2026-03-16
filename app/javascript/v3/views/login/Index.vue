<script>
// utils and composables
import { login } from '../../api/auth';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { SESSION_STORAGE_KEYS } from 'dashboard/constants/sessionStorage';
import SessionStorage from 'shared/helpers/sessionStorage';
import { useBranding } from 'shared/composables/useBranding';

// components
import SimpleDivider from '../../components/Divider/SimpleDivider.vue';
import FormInput from '../../components/Form/Input.vue';
import GoogleOAuthButton from '../../components/GoogleOauth/Button.vue';
import VkIdOAuthButton from '../../components/VkIdOauth/Button.vue';
import YandexOAuthButton from '../../components/YandexOauth/Button.vue';
import Spinner from 'shared/components/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import MfaVerification from 'dashboard/components/auth/MfaVerification.vue';

const ERROR_MESSAGES = {
  'no-account-found': 'LOGIN.OAUTH.NO_ACCOUNT_FOUND',
  'business-account-only': 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY',
  'saml-authentication-failed': 'LOGIN.SAML.API.ERROR_MESSAGE',
  'saml-not-enabled': 'LOGIN.SAML.API.ERROR_MESSAGE',
};

const IMPERSONATION_URL_SEARCH_KEY = 'impersonation';

export default {
  components: {
    FormInput,
    GoogleOAuthButton,
    VkIdOAuthButton,
    YandexOAuthButton,
    Spinner,
    NextButton,
    SimpleDivider,
    MfaVerification,
    Icon,
  },
  props: {
    ssoAuthToken: { type: String, default: '' },
    ssoAccountId: { type: String, default: '' },
    ssoConversationId: { type: String, default: '' },
    email: { type: String, default: '' },
    authError: { type: String, default: '' },
  },
  setup() {
    const { replaceInstallationName } = useBranding();
    return {
      replaceInstallationName,
      v$: useVuelidate(),
    };
  },
  data() {
    return {
      credentials: {
        email: '',
        password: '',
      },
      loginApi: {
        message: '',
        showLoading: false,
        hasErrored: false,
      },
      error: '',
      mfaRequired: false,
      mfaToken: null,
    };
  },
  validations() {
    return {
      credentials: {
        password: {
          required,
        },
        email: {
          required,
          email,
        },
      },
    };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
    allowedLoginMethods() {
      return window.chatwootConfig.allowedLoginMethods || ['email'];
    },
    showGoogleOAuth() {
      return (
        this.allowedLoginMethods.includes('google_oauth') &&
        Boolean(window.chatwootConfig.googleOAuthClientId)
      );
    },
    showSignupLink() {
      return window.chatwootConfig.signupEnabled === 'true';
    },
    showVkIdOAuth() {
      return (
        this.allowedLoginMethods.includes('vk_id_oauth') &&
        Boolean(window.chatwootConfig.vkIdClientId)
      );
    },
    showYandexOAuth() {
      return (
        this.allowedLoginMethods.includes('yandex_oauth') &&
        Boolean(window.chatwootConfig.yandexOAuthClientId)
      );
    },
    showSamlLogin() {
      return this.allowedLoginMethods.includes('saml');
    },
    hasSocialLogin() {
      return (
        this.showGoogleOAuth ||
        this.showVkIdOAuth ||
        this.showYandexOAuth ||
        this.showSamlLogin
      );
    },
  },
  created() {
    if (this.ssoAuthToken) {
      this.submitLogin();
    }
    if (this.authError) {
      const messageKey = ERROR_MESSAGES[this.authError] ?? 'LOGIN.API.UNAUTH';
      const translatedMessage = this.getTranslatedMessage(messageKey);
      useAlert(translatedMessage);
      this.requestIdleCallbackPolyfill(() => {
        const { query } = this.$route;
        this.$router.replace({ query: { ...query, error: undefined } });
      });
    }
  },
  methods: {
    getTranslatedMessage(key) {
      switch (key) {
        case 'LOGIN.OAUTH.NO_ACCOUNT_FOUND':
          return this.$t('LOGIN.OAUTH.NO_ACCOUNT_FOUND');
        case 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY':
          return this.$t('LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY');
        case 'LOGIN.API.UNAUTH':
        default:
          return this.$t('LOGIN.API.UNAUTH');
      }
    },
    requestIdleCallbackPolyfill(callback) {
      if (window.requestIdleCallback) {
        window.requestIdleCallback(callback);
      } else {
        setTimeout(callback, 0);
      }
    },
    showAlertMessage(message) {
      this.loginApi.showLoading = false;
      this.loginApi.message = message;
      useAlert(this.loginApi.message);
    },
    handleImpersonation() {
      const urlParams = new URLSearchParams(window.location.search);
      const impersonation = urlParams.get(IMPERSONATION_URL_SEARCH_KEY);
      if (impersonation) {
        SessionStorage.set(SESSION_STORAGE_KEYS.IMPERSONATION_USER, true);
      }
    },
    submitLogin() {
      this.loginApi.hasErrored = false;
      this.loginApi.showLoading = true;

      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
      };

      login(credentials)
        .then(result => {
          if (result?.mfaRequired) {
            this.loginApi.showLoading = false;
            this.mfaRequired = true;
            this.mfaToken = result.mfaToken;
            return;
          }

          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          if (this.email) {
            window.location = '/app/login';
          }
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    submitFormLogin() {
      if (this.v$.credentials.email.$invalid && !this.email) {
        this.showAlertMessage(this.$t('LOGIN.EMAIL.ERROR'));
        return;
      }

      this.submitLogin();
    },
    handleMfaVerified() {
      this.handleImpersonation();
      window.location = '/app';
    },
    handleMfaCancel() {
      this.mfaRequired = false;
      this.mfaToken = null;
      this.credentials.password = '';
    },
  },
};
</script>

<template>
  <main
    class="flex items-center justify-center w-full min-h-screen bg-gradient-to-br from-n-brand/5 via-n-background to-n-brand/10 dark:from-n-background dark:via-n-solid-1 dark:to-n-background sm:px-6 lg:px-8"
  >
    <div class="w-full max-w-md mx-auto py-12">
      <!-- Logo & Header -->
      <section class="text-center mb-8">
        <div class="flex justify-center mb-6">
          <div class="p-3 rounded-2xl bg-white dark:bg-n-solid-2 shadow-sm">
            <img
              :src="globalConfig.logo"
              :alt="globalConfig.installationName"
              class="block w-auto h-10 dark:hidden"
            />
            <img
              v-if="globalConfig.logoDark"
              :src="globalConfig.logoDark"
              :alt="globalConfig.installationName"
              class="hidden w-auto h-10 dark:block"
            />
          </div>
        </div>
        <h1 class="text-2xl font-bold text-n-slate-12">
          {{ replaceInstallationName($t('LOGIN.TITLE')) }}
        </h1>
        <p class="mt-2 text-sm text-n-slate-11">
          {{ $t('LOGIN.SUBTITLE') }}
        </p>
      </section>

      <!-- MFA Verification Section -->
      <section v-if="mfaRequired">
        <MfaVerification
          :mfa-token="mfaToken"
          @verified="handleMfaVerified"
          @cancel="handleMfaCancel"
        />
      </section>

      <!-- Regular Login Section -->
      <section
        v-else
        class="bg-white dark:bg-n-solid-2 rounded-2xl shadow-lg ring-1 ring-n-container/50 dark:ring-n-container p-8"
        :class="{
          'animate-wiggle': loginApi.hasErrored,
        }"
      >
        <div v-if="!email">
          <!-- Social Login Buttons -->
          <div v-if="hasSocialLogin" class="flex flex-col gap-3">
            <GoogleOAuthButton v-if="showGoogleOAuth" />
            <VkIdOAuthButton v-if="showVkIdOAuth" />
            <YandexOAuthButton v-if="showYandexOAuth" />
            <div v-if="showSamlLogin">
              <router-link
                to="/app/login/sso"
                class="inline-flex justify-center w-full px-4 py-3 items-center bg-n-background dark:bg-n-solid-3 rounded-xl shadow-sm ring-1 ring-inset ring-n-container dark:ring-n-container focus:outline-offset-0 hover:bg-n-alpha-2 dark:hover:bg-n-alpha-2 transition-colors"
              >
                <Icon
                  icon="i-lucide-lock-keyhole"
                  class="size-5 text-n-slate-11"
                />
                <span class="ml-2 text-base font-medium text-n-slate-12">
                  {{ $t('LOGIN.SAML.LABEL') }}
                </span>
              </router-link>
            </div>
            <SimpleDivider
              :label="$t('LOGIN.EMAIL_SECTION_TITLE')"
              class="mt-2"
            />
          </div>

          <!-- Email Login Form -->
          <form class="space-y-4" @submit.prevent="submitFormLogin">
            <FormInput
              v-model="credentials.email"
              name="email_address"
              type="text"
              data-testid="email_input"
              :tabindex="1"
              required
              :label="$t('LOGIN.EMAIL.LABEL')"
              :placeholder="$t('LOGIN.EMAIL.PLACEHOLDER')"
              :has-error="v$.credentials.email.$error"
              @input="v$.credentials.email.$touch"
            />
            <FormInput
              v-model="credentials.password"
              type="password"
              name="password"
              data-testid="password_input"
              required
              :tabindex="2"
              :label="$t('LOGIN.PASSWORD.LABEL')"
              :placeholder="$t('LOGIN.PASSWORD.PLACEHOLDER')"
              :has-error="v$.credentials.password.$error"
              @input="v$.credentials.password.$touch"
            >
              <p v-if="!globalConfig.disableUserProfileUpdate">
                <router-link
                  to="auth/reset/password"
                  class="text-sm text-n-brand hover:text-n-brand/80 transition-colors"
                  tabindex="4"
                >
                  {{ $t('LOGIN.FORGOT_PASSWORD') }}
                </router-link>
              </p>
            </FormInput>
            <NextButton
              lg
              type="submit"
              data-testid="submit_button"
              class="w-full"
              :tabindex="3"
              :label="$t('LOGIN.SUBMIT')"
              :disabled="loginApi.showLoading"
              :is-loading="loginApi.showLoading"
            />
          </form>
        </div>
        <div v-else class="flex items-center justify-center py-8">
          <Spinner color-scheme="primary" size="" />
        </div>
      </section>

      <!-- Sign Up Link -->
      <p v-if="showSignupLink" class="mt-6 text-center text-sm text-n-slate-11">
        {{ $t('LOGIN.NO_ACCOUNT') }}
        {{ ' ' }}
        <router-link
          to="auth/signup"
          class="font-semibold text-n-brand hover:text-n-brand/80 transition-colors"
        >
          {{ $t('LOGIN.SIGN_UP_LINK') }}
        </router-link>
      </p>
    </div>
  </main>
</template>
