<script setup>
import {
  ref,
  reactive,
  computed,
  markRaw,
  watch,
  onMounted,
  onUnmounted,
} from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import {
  setAccountScopedPathOverride,
  clearAccountScopedPathOverride,
} from 'dashboard/api/ApiClient';
import WelcomeStep from './steps/WelcomeStep.vue';
import UseCaseStep from './steps/UseCaseStep.vue';
import BusinessContextStep from './steps/BusinessContextStep.vue';
import ChannelsStep from './steps/ChannelsStep.vue';
import MigrationStep from './steps/MigrationStep.vue';
import CompleteStep from './steps/CompleteStep.vue';

const BUSINESS_CONTEXT_STEP_INDEX = 2;
const CHANNEL_STEP_INDEX = 3;
const MIGRATION_STEP_INDEX = 4;

const store = useStore();
const { t } = useI18n();

const STEPS = [
  markRaw(WelcomeStep),
  markRaw(UseCaseStep),
  markRaw(BusinessContextStep),
  markRaw(ChannelsStep),
  markRaw(MigrationStep),
  markRaw(CompleteStep),
];

const currentStep = ref(0);
const slideDirection = ref('forward');

const currentUser = computed(() => store.getters.getCurrentUser);

const wizardData = reactive({
  displayName: currentUser.value?.display_name || currentUser.value?.name || '',
  useCase: '',
  businessContext: null,
  channels: [],
});

const totalSteps = STEPS.length;
const isLastStep = computed(() => currentStep.value === totalSteps - 1);
const currentComponent = computed(() => STEPS[currentStep.value]);

const showBackButton = computed(
  () => currentStep.value > 0 && currentStep.value < totalSteps - 1
);
const showNextButton = computed(() => {
  return (
    currentStep.value === 0 ||
    currentStep.value === 1 ||
    currentStep.value === BUSINESS_CONTEXT_STEP_INDEX ||
    currentStep.value === CHANNEL_STEP_INDEX ||
    currentStep.value === MIGRATION_STEP_INDEX
  );
});

const cardMaxWidthClass = computed(() =>
  currentStep.value === MIGRATION_STEP_INDEX ? 'max-w-2xl' : 'max-w-lg'
);

function applyAccountScopedApiOverride() {
  const user = store.getters.getCurrentUser;
  const id = user?.account_id || user?.accounts?.[0]?.id;
  if (id) setAccountScopedPathOverride(id);
}

onMounted(() => applyAccountScopedApiOverride());

watch(
  () => store.getters.getCurrentUser,
  () => applyAccountScopedApiOverride(),
  { deep: true }
);

onUnmounted(() => {
  clearAccountScopedPathOverride();
});

function goNext(data = {}) {
  Object.assign(wizardData, data);
  if (currentStep.value < totalSteps - 1) {
    slideDirection.value = 'forward';
    currentStep.value += 1;
  }
}

function goBack() {
  if (currentStep.value > 0) {
    slideDirection.value = 'backward';
    currentStep.value -= 1;
  }
}

function skip() {
  window.location = '/app';
}

async function finish() {
  if (wizardData.displayName) {
    await store.dispatch('updateProfile', {
      displayName: wizardData.displayName,
    });
  }
  if (wizardData.businessContext) {
    const accountId =
      currentUser.value?.account_id || currentUser.value?.accounts?.[0]?.id;
    if (accountId) {
      try {
        await store.dispatch('accounts/update', {
          id: accountId,
          business_context: wizardData.businessContext,
        });
      } catch (_error) {
        // Ignore and continue onboarding completion.
      }
    }
  }
  window.location = '/app';
}

function handleNext() {
  if (currentStep.value === 0) {
    goNext({ displayName: wizardData.displayName });
  } else if (currentStep.value === 1) {
    goNext({ useCase: wizardData.useCase });
  } else if (currentStep.value === BUSINESS_CONTEXT_STEP_INDEX) {
    goNext({ businessContext: wizardData.businessContext });
  } else if (currentStep.value === CHANNEL_STEP_INDEX) {
    goNext({ channels: wizardData.channels });
  } else if (currentStep.value === MIGRATION_STEP_INDEX) {
    goNext();
  }
}

function handleStepNext(data) {
  goNext(data);
}

function handleStepUpdate(data) {
  Object.assign(wizardData, data);
}
</script>

<template>
  <main
    class="flex items-center justify-center w-full min-h-screen bg-gradient-to-br from-n-brand/5 via-n-background to-n-brand/10 dark:from-n-background dark:via-n-solid-1 dark:to-n-background p-4"
  >
    <div
      class="w-full mx-auto flex flex-col bg-white dark:bg-n-solid-2 rounded-2xl shadow-lg ring-1 ring-n-container/50 dark:ring-n-container overflow-hidden transition-[max-width] duration-300"
      :class="cardMaxWidthClass"
    >
      <!-- Header -->
      <div class="flex items-center justify-end px-6 pt-4">
        <button
          v-if="!isLastStep"
          class="text-sm text-n-slate-10 hover:text-n-slate-12 transition-colors"
          @click="skip"
        >
          {{ t('ONBOARDING_WIZARD.SKIP') }}
        </button>
      </div>

      <!-- Content -->
      <div
        class="px-8 py-8"
        :class="
          currentStep === MIGRATION_STEP_INDEX ? 'min-h-0 flex flex-col' : ''
        "
      >
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
            :initial-name="wizardData.displayName"
            :initial-use-case="wizardData.useCase"
            :initial-business-type="wizardData.businessContext?.business_type"
            :initial-description="wizardData.businessContext?.description"
            :initial-channels="wizardData.channels"
            @next="handleStepNext"
            @update="handleStepUpdate"
            @finish="finish"
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
            :label="t('ONBOARDING_WIZARD.BACK')"
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

        <div>
          <NextButton
            v-if="showNextButton"
            sm
            :label="t('ONBOARDING_WIZARD.NEXT')"
            @click="handleNext"
          />
          <div v-else class="w-16" />
        </div>
      </div>
    </div>
  </main>
</template>
