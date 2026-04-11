<script setup>
import { ref, computed, markRaw, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import AgentsAPI from 'dashboard/api/agents';
import ProfileStep from './steps/ProfileStep.vue';
import AccountStep from './steps/AccountStep.vue';
import InviteStep from './steps/InviteStep.vue';
import InboxStep from './steps/InboxStep.vue';
import GreetingStep from './steps/GreetingStep.vue';
import CannedResponseStep from './steps/CannedResponseStep.vue';
import MigrationStep from './steps/MigrationStep.vue';
import CompleteStep from './steps/CompleteStep.vue';

const STEPS = [
  markRaw(ProfileStep),
  markRaw(AccountStep),
  markRaw(InviteStep),
  markRaw(InboxStep),
  markRaw(GreetingStep),
  markRaw(CannedResponseStep),
  markRaw(MigrationStep),
  markRaw(CompleteStep),
];

const STEP_KEYS = [
  'profile',
  'account',
  'invite',
  'inbox',
  'greeting',
  'canned',
  'migration',
  'complete',
];

const GREETING_STEP_INDEX = 4;

const { t } = useI18n();
const router = useRouter();
const store = useStore();
const { accountId, currentAccount, updateAccount } = useAccount();

const currentStep = ref(0);
const slideDirection = ref('forward');
const isSaving = ref(false);
const lastError = ref(null);

const profileSet = ref(false);
const agentsInvited = ref(0);
const inboxCreated = ref(false);
const createdInboxId = ref(null);
const greetingSet = ref(false);
const cannedResponsesCreated = ref(0);

const totalSteps = STEPS.length;
const isLastStep = computed(() => currentStep.value === totalSteps - 1);
const currentComponent = computed(() => STEPS[currentStep.value]);
const showBackButton = computed(
  () => currentStep.value > 0 && currentStep.value < totalSteps - 1
);
const stepProgress = computed(() => `${currentStep.value + 1} / ${totalSteps}`);

onMounted(async () => {
  await store.dispatch('accounts/get');
  const savedStep = currentAccount.value?.custom_attributes?.onboarding_step;
  if (savedStep) {
    const idx = STEP_KEYS.indexOf(savedStep);
    if (idx >= 0) {
      currentStep.value = idx;
    }
  }
});

async function saveOnboardingStep(stepKey) {
  try {
    await updateAccount({ onboarding_step: stepKey });
  } catch {
    // Step persistence is best-effort
  }
}

function goForward() {
  if (currentStep.value < totalSteps - 1) {
    slideDirection.value = 'forward';
    lastError.value = null;
    let next = currentStep.value + 1;
    if (next === GREETING_STEP_INDEX && !createdInboxId.value) {
      next += 1;
    }
    currentStep.value = next;
    saveOnboardingStep(STEP_KEYS[currentStep.value]);
  }
}

function goBack() {
  if (currentStep.value > 0) {
    slideDirection.value = 'backward';
    lastError.value = null;
    let prev = currentStep.value - 1;
    if (prev === GREETING_STEP_INDEX && !createdInboxId.value) {
      prev -= 1;
    }
    currentStep.value = prev;
  }
}

function getInboxIdFromStore() {
  const inboxes = store.getters['inboxes/getInboxes'];
  if (inboxes && inboxes.length > 0) {
    return inboxes[inboxes.length - 1].id;
  }
  return null;
}

async function handleProfileNext(data) {
  isSaving.value = true;
  lastError.value = null;
  try {
    await store.dispatch('auth/updateProfile', {
      displayName: data.displayName,
    });
    profileSet.value = true;
    useAlert(t('ONBOARDING.PROFILE_STEP.SUCCESS'));
    goForward();
  } catch (error) {
    lastError.value =
      error.response?.data?.message || t('ONBOARDING.PROFILE_STEP.ERROR');
    useAlert(lastError.value);
  } finally {
    isSaving.value = false;
  }
}

async function handleAccountNext(data) {
  isSaving.value = true;
  lastError.value = null;
  try {
    await updateAccount({
      name: data.name,
      locale: data.locale,
      timezone: data.timezone,
    });
    useAlert(t('ONBOARDING.ACCOUNT_STEP.SUCCESS'));
    goForward();
  } catch (error) {
    lastError.value =
      error.response?.data?.message || t('ONBOARDING.ACCOUNT_STEP.ERROR');
    useAlert(lastError.value);
  } finally {
    isSaving.value = false;
  }
}

async function handleInviteNext(data) {
  if (!data.emails.length) {
    goForward();
    return;
  }
  isSaving.value = true;
  lastError.value = null;
  try {
    await AgentsAPI.bulkInvite({ emails: data.emails });
    agentsInvited.value = data.emails.length;
    useAlert(t('ONBOARDING.INVITE_STEP.SUCCESS'));
    goForward();
  } catch (error) {
    const errorMsg = error.response?.data?.message;
    if (errorMsg?.includes('already')) {
      lastError.value = t('ONBOARDING.INVITE_STEP.ERROR_DUPLICATE');
    } else {
      lastError.value = errorMsg || t('ONBOARDING.INVITE_STEP.ERROR');
    }
    useAlert(lastError.value);
  } finally {
    isSaving.value = false;
  }
}

function buildChannelParams(data) {
  switch (data.channelType) {
    case 'website':
      return {
        action: 'inboxes/createWebsiteChannel',
        params: {
          name: data.inboxName,
          channel: { type: 'web_widget', website_url: data.websiteUrl },
        },
      };
    case 'email':
      return {
        action: 'inboxes/createChannel',
        params: {
          name: data.inboxName,
          channel: { type: 'email', email: data.emailAddress },
        },
      };
    case 'telegram':
      return {
        action: 'inboxes/createChannel',
        params: {
          channel: { type: 'telegram', bot_token: data.botToken },
        },
      };
    case 'whatsapp':
      return {
        action: 'inboxes/createChannel',
        params: {
          name: data.inboxName,
          channel: {
            type: 'whatsapp',
            phone_number: data.phoneNumber,
            provider: 'default',
          },
        },
      };
    case 'api':
      return {
        action: 'inboxes/createChannel',
        params: {
          name: data.inboxName,
          channel: { type: 'api', webhook_url: data.webhookUrl },
        },
      };
    case 'vk':
      return {
        action: 'inboxes/createChannel',
        params: {
          channel: {
            type: 'vk',
            group_id: data.groupId,
            access_token: data.accessToken,
          },
        },
      };
    case 'avito':
      return {
        action: 'inboxes/createChannel',
        params: {
          name: data.inboxName,
          channel: {
            type: 'avito',
            client_id: data.clientId,
            client_secret: data.clientSecret,
          },
        },
      };
    default:
      return null;
  }
}

async function handleInboxNext(data) {
  const channelConfig = buildChannelParams(data);
  if (!channelConfig) {
    goForward();
    return;
  }
  isSaving.value = true;
  lastError.value = null;
  try {
    const result = await store.dispatch(
      channelConfig.action,
      channelConfig.params
    );
    createdInboxId.value = result?.id || getInboxIdFromStore();
    inboxCreated.value = !!createdInboxId.value;
    useAlert(t('ONBOARDING.INBOX_STEP.SUCCESS'));
    goForward();
  } catch (error) {
    lastError.value =
      error.response?.data?.message || t('ONBOARDING.INBOX_STEP.ERROR');
    useAlert(lastError.value);
  } finally {
    isSaving.value = false;
  }
}

async function handleGreetingNext(data) {
  if (!createdInboxId.value || !data.greetingEnabled) {
    goForward();
    return;
  }
  isSaving.value = true;
  lastError.value = null;
  try {
    await store.dispatch('inboxes/updateInbox', {
      id: createdInboxId.value,
      formData: false,
      greeting_enabled: data.greetingEnabled,
      greeting_message: data.greetingMessage,
      channel: {},
    });
    greetingSet.value = true;
    useAlert(t('ONBOARDING.GREETING_STEP.SUCCESS'));
    goForward();
  } catch (error) {
    lastError.value =
      error.response?.data?.message || t('ONBOARDING.GREETING_STEP.ERROR');
    useAlert(lastError.value);
  } finally {
    isSaving.value = false;
  }
}

async function handleCannedNext(data) {
  if (!data.responses.length) {
    goForward();
    return;
  }
  isSaving.value = true;
  lastError.value = null;
  try {
    const results = await Promise.allSettled(
      data.responses.map(r =>
        store.dispatch('cannedResponse/createCannedResponse', {
          short_code: r.shortCode,
          content: r.content,
        })
      )
    );
    const succeeded = results.filter(r => r.status === 'fulfilled').length;
    const failed = results.length - succeeded;
    cannedResponsesCreated.value = succeeded;
    if (failed > 0 && succeeded > 0) {
      useAlert(
        t('ONBOARDING.CANNED_STEP.PARTIAL_SUCCESS', {
          succeeded,
          failed,
        })
      );
    } else if (failed > 0) {
      lastError.value = t('ONBOARDING.CANNED_STEP.ERROR');
      useAlert(lastError.value);
      return;
    } else {
      useAlert(t('ONBOARDING.CANNED_STEP.SUCCESS'));
    }
    goForward();
  } catch (error) {
    lastError.value =
      error.response?.data?.message || t('ONBOARDING.CANNED_STEP.ERROR');
    useAlert(lastError.value);
  } finally {
    isSaving.value = false;
  }
}

const STEP_HANDLERS = [
  handleProfileNext,
  handleAccountNext,
  handleInviteNext,
  handleInboxNext,
  handleGreetingNext,
  handleCannedNext,
  () => {},
];

function handleStepNext(data) {
  const handler = STEP_HANDLERS[currentStep.value];
  if (handler) handler(data);
}

function handleSkip() {
  goForward();
}

function handleFinish() {
  saveOnboardingStep('complete');
  router.push({
    name: 'home',
    params: { accountId: accountId.value },
  });
}

function handleRetry() {
  lastError.value = null;
}
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-gradient-to-br from-n-brand/5 via-n-background to-n-brand/10 dark:from-n-background dark:via-n-solid-1 dark:to-n-background p-4"
  >
    <div
      class="w-full max-w-lg mx-auto flex flex-col bg-white dark:bg-n-solid-2 rounded-2xl shadow-lg ring-1 ring-n-container/50 dark:ring-n-container overflow-hidden"
    >
      <!-- Header -->
      <div class="flex items-center justify-between px-6 pt-4">
        <span class="text-xs text-n-slate-9 font-medium">
          {{ stepProgress }}
        </span>
        <button
          v-if="!isLastStep"
          class="text-sm text-n-slate-10 hover:text-n-slate-12 transition-colors"
          :disabled="isSaving"
          @click="handleSkip"
        >
          {{ t('ONBOARDING.SKIP') }}
        </button>
      </div>

      <!-- Content -->
      <div class="px-8 py-8">
        <Transition
          enter-active-class="transition duration-300 ease-in-out"
          :enter-from-class="
            slideDirection === 'forward'
              ? 'translate-x-8 opacity-0'
              : '-translate-x-8 opacity-0'
          "
          enter-to-class="translate-x-0 opacity-100"
          leave-active-class="transition duration-200 ease-in"
          leave-from-class="translate-x-0 opacity-100"
          :leave-to-class="
            slideDirection === 'forward'
              ? '-translate-x-8 opacity-0'
              : 'translate-x-8 opacity-0'
          "
          mode="out-in"
        >
          <component
            :is="currentComponent"
            :key="currentStep"
            :is-saving="isSaving"
            :last-error="lastError"
            :profile-set="profileSet"
            :agents-invited="agentsInvited"
            :inbox-created="inboxCreated"
            :inbox-id="createdInboxId"
            :greeting-set="greetingSet"
            :canned-responses-created="cannedResponsesCreated"
            @next="handleStepNext"
            @finish="handleFinish"
            @retry="handleRetry"
          />
        </Transition>
      </div>

      <!-- Footer -->
      <div class="flex items-center justify-between px-8 pb-6">
        <div>
          <NextButton
            v-if="showBackButton"
            variant="ghost"
            color="slate"
            sm
            :label="t('ONBOARDING.BACK')"
            :disabled="isSaving"
            @click="goBack"
          />
        </div>

        <!-- Progress dots -->
        <div class="flex items-center gap-2">
          <span
            v-for="i in totalSteps"
            :key="i"
            class="w-2 h-2 rounded-full transition-colors duration-300"
            :class="i - 1 === currentStep ? 'bg-n-brand' : 'bg-n-slate-4'"
          />
        </div>

        <div class="w-16" />
      </div>
    </div>
  </div>
</template>
