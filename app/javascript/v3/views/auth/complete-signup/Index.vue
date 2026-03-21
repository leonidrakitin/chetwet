<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useToast } from 'dashboard/composables';
import { isValidPassword } from 'shared/helpers/Validators';
import { completeOauthSignup } from '../../../api/auth';
import FormInput from '../../../components/Form/Input.vue';
import FormCheckBox from '../../../components/Form/CheckBox.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PasswordRequirements from '../signup/components/Signup/PasswordRequirements.vue';

const props = defineProps({
  signupToken: { type: String, default: '' },
  email: { type: String, default: '' },
});

const MIN_PASSWORD_LENGTH = 6;

const store = useStore();
const { t } = useI18n();

const password = ref('');
const isPasswordFocused = ref(false);
const isSubmitting = ref(false);
const consentPersonalData = ref(false);
const consentMarketing = ref(false);
const showConsentError = ref(false);

const rules = {
  password: {
    required,
    isValidPassword,
    minLength: minLength(MIN_PASSWORD_LENGTH),
  },
};

const v$ = useVuelidate(rules, { password });

const globalConfig = computed(() => store.getters['globalConfig/get']);
const decodedEmail = computed(() =>
  props.email ? decodeURIComponent(props.email) : ''
);
const isConsentValid = computed(() => consentPersonalData.value);

onMounted(() => {
  if (!props.signupToken) {
    window.location = '/app/login';
  }
});

const handleConsentPersonalData = (_value, checked) => {
  consentPersonalData.value = checked;
  if (checked) showConsentError.value = false;
};

const handleConsentMarketing = (_value, checked) => {
  consentMarketing.value = checked;
};

const submit = async () => {
  if (isSubmitting.value) return;

  if (!isConsentValid.value) {
    showConsentError.value = true;
    useToast.warning(t('REGISTER.CONSENT.REQUIRED'));
    return;
  }
  showConsentError.value = false;

  v$.value.$touch();
  if (v$.value.$invalid) return;

  isSubmitting.value = true;
  try {
    const result = await completeOauthSignup({
      signupToken: props.signupToken,
      password: password.value,
    });
    if (result) {
      window.location = '/app/onboarding/wizard';
    }
  } catch {
    useToast.error(t('REGISTER.COMPLETE_SIGNUP.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
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
          {{ $t('REGISTER.COMPLETE_SIGNUP.TITLE') }}
        </h1>
        <p class="mt-2 text-sm text-n-slate-11">
          {{ $t('REGISTER.COMPLETE_SIGNUP.SUBTITLE') }}
        </p>
      </section>

      <!-- Form -->
      <section
        class="bg-white dark:bg-n-solid-2 rounded-2xl shadow-lg ring-1 ring-n-container/50 dark:ring-n-container p-8"
      >
        <form class="space-y-4" @submit.prevent="submit">
          <FormInput
            :model-value="decodedEmail"
            type="email"
            name="email_address"
            :label="$t('LOGIN.EMAIL.LABEL')"
            readonly
          />

          <div class="relative">
            <FormInput
              v-model="password"
              type="password"
              name="password"
              :label="$t('LOGIN.PASSWORD.LABEL')"
              :placeholder="$t('SET_NEW_PASSWORD.PASSWORD.PLACEHOLDER')"
              :has-error="v$.password.$error"
              @focus="isPasswordFocused = true"
              @blur="
                isPasswordFocused = false;
                v$.password.$touch();
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
                :password="password"
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

          <NextButton
            lg
            type="submit"
            class="w-full font-medium"
            :label="$t('REGISTER.COMPLETE_SIGNUP.SUBMIT')"
            :disabled="isSubmitting"
            :is-loading="isSubmitting"
          />
        </form>
      </section>
    </div>
  </main>
</template>
