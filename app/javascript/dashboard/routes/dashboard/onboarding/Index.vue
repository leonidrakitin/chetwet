<script setup>
import { ref, computed, markRaw, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import AgentsAPI from 'dashboard/api/agents';
import AccountStep from './steps/AccountStep.vue';
import InviteStep from './steps/InviteStep.vue';
import InboxStep from './steps/InboxStep.vue';
import CompleteStep from './steps/CompleteStep.vue';

const STEPS = [
  markRaw(AccountStep),
  markRaw(InviteStep),
  markRaw(InboxStep),
  markRaw(CompleteStep),
];

const STEP_KEYS = ['account', 'invite', 'inbox', 'complete'];

const { t } = useI18n();
const router = useRouter();
const store = useStore();
const { accountId, currentAccount, updateAccount } = useAccount();

const currentStep = ref(0);
const slideDirection = ref('forward');
const isSaving = ref(false);
const agentsInvited = ref(0);
const inboxCreated = ref(false);

const totalSteps = STEPS.length;
const isLastStep = computed(() => currentStep.value === totalSteps - 1);
const currentComponent = computed(() => STEPS[currentStep.value]);
const showBackButton = computed(
  () => currentStep.value > 0 && currentStep.value < totalSteps - 1
);

// Restore step from server on mount
onMounted(async () => {
  await store.dispatch('accounts/get');
  const savedStep = currentAccount.value?.custom_attributes?.onboarding_step;
  if (savedStep) {
    const idx = STEP_KEYS.indexOf(savedStep);
    if (idx > 0) {
      currentStep.value = idx;
    }
  }
});

async function saveOnboardingStep(stepKey) {
  try {
    await updateAccount({
      onboarding_step: stepKey,
    });
  } catch {
    // Step persistence is best-effort
  }
}

function goForward() {
  if (currentStep.value < totalSteps - 1) {
    slideDirection.value = 'forward';
    currentStep.value += 1;
    saveOnboardingStep(STEP_KEYS[currentStep.value]);
  }
}

function goBack() {
  if (currentStep.value > 0) {
    slideDirection.value = 'backward';
    currentStep.value -= 1;
  }
}

async function handleAccountNext(data) {
  isSaving.value = true;
  try {
    await updateAccount({
      name: data.name,
      locale: data.locale,
    });
    useAlert(t('ONBOARDING.ACCOUNT_STEP.SUCCESS'));
    goForward();
  } catch {
    useAlert(t('ONBOARDING.ACCOUNT_STEP.ERROR'));
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
  try {
    await AgentsAPI.bulkInvite({ emails: data.emails });
    agentsInvited.value = data.emails.length;
    useAlert(t('ONBOARDING.INVITE_STEP.SUCCESS'));
    goForward();
  } catch {
    useAlert(t('ONBOARDING.INVITE_STEP.ERROR'));
  } finally {
    isSaving.value = false;
  }
}

async function handleInboxNext(data) {
  if (!data.inboxName) {
    goForward();
    return;
  }
  isSaving.value = true;
  try {
    if (data.channelType === 'website') {
      await store.dispatch('inboxes/createWebsiteChannel', {
        name: data.inboxName,
        channel: {
          type: 'web_widget',
          website_url: data.websiteUrl,
        },
      });
    } else {
      await store.dispatch('inboxes/createChannel', {
        name: data.inboxName,
        channel: {
          type: 'email',
          email: data.emailAddress,
        },
      });
    }
    inboxCreated.value = true;
    useAlert(t('ONBOARDING.INBOX_STEP.SUCCESS'));
    goForward();
  } catch {
    useAlert(t('ONBOARDING.INBOX_STEP.ERROR'));
  } finally {
    isSaving.value = false;
  }
}

function handleStepNext(data) {
  if (currentStep.value === 0) handleAccountNext(data);
  else if (currentStep.value === 1) handleInviteNext(data);
  else if (currentStep.value === 2) handleInboxNext(data);
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
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-gradient-to-br from-n-brand/5 via-n-background to-n-brand/10 dark:from-n-background dark:via-n-solid-1 dark:to-n-background p-4"
  >
    <div
      class="w-full max-w-lg mx-auto flex flex-col bg-white dark:bg-n-solid-2 rounded-2xl shadow-lg ring-1 ring-n-container/50 dark:ring-n-container overflow-hidden"
    >
      <!-- Header -->
      <div class="flex items-center justify-end px-6 pt-4">
        <button
          v-if="!isLastStep && currentStep > 0"
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
            :agents-invited="agentsInvited"
            :inbox-created="inboxCreated"
            :is-saving="isSaving"
            @next="handleStepNext"
            @finish="handleFinish"
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
