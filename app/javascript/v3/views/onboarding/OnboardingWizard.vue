<script setup>
import { ref, reactive, computed, markRaw } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import WelcomeStep from './steps/WelcomeStep.vue';
import UseCaseStep from './steps/UseCaseStep.vue';
import ChannelsStep from './steps/ChannelsStep.vue';
import CompleteStep from './steps/CompleteStep.vue';

const store = useStore();
const { t } = useI18n();

const STEPS = [
  markRaw(WelcomeStep),
  markRaw(UseCaseStep),
  markRaw(ChannelsStep),
  markRaw(CompleteStep),
];

const currentStep = ref(0);
const slideDirection = ref('forward');

const wizardData = reactive({
  displayName: '',
  useCase: '',
  channels: [],
});

const totalSteps = STEPS.length;
const isLastStep = computed(() => currentStep.value === totalSteps - 1);
const currentComponent = computed(() => STEPS[currentStep.value]);

const showBackButton = computed(
  () => currentStep.value > 0 && currentStep.value < totalSteps - 1
);
const showNextButton = computed(() => {
  // Welcome step and Channels step have explicit continue buttons
  // UseCase auto-advances on click, Complete has its own CTA
  return currentStep.value === 0 || currentStep.value === 2;
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
    await store.dispatch('auth/updateProfile', {
      displayName: wizardData.displayName,
    });
  }
  window.location = '/app';
}

function handleNext() {
  if (currentStep.value === 0) {
    goNext({ displayName: wizardData.displayName });
  } else if (currentStep.value === 2) {
    goNext({ channels: wizardData.channels });
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
      class="w-full max-w-lg mx-auto flex flex-col bg-white dark:bg-n-solid-2 rounded-2xl shadow-lg ring-1 ring-n-container/50 dark:ring-n-container overflow-hidden"
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
            :initial-name="wizardData.displayName"
            :initial-use-case="wizardData.useCase"
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
