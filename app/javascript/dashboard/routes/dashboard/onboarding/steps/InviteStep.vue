<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  isSaving: { type: Boolean, default: false },
  lastError: { type: String, default: null },
});

const emit = defineEmits(['next', 'retry']);
const { t } = useI18n();
const store = useStore();

const emailInput = ref('');
const emails = ref([]);

const agents = computed(() => store.getters['agents/getAgents']);

onMounted(() => {
  store.dispatch('agents/get');
});

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function addEmail() {
  const val = emailInput.value.trim().toLowerCase();
  if (val && isValidEmail(val) && !emails.value.includes(val)) {
    emails.value.push(val);
  }
  emailInput.value = '';
}

function removeEmail(email) {
  emails.value = emails.value.filter(e => e !== email);
}

function handleKeydown(event) {
  if (event.key === 'Enter' || event.key === ',') {
    event.preventDefault();
    addEmail();
  }
  if (event.key === 'Backspace' && !emailInput.value && emails.value.length) {
    emails.value.pop();
  }
}

function proceed() {
  addEmail();
  emit('next', { emails: [...emails.value] });
}
</script>

<template>
  <div class="flex flex-col items-center text-center px-2">
    <div
      class="flex items-center justify-center w-16 h-16 rounded-2xl bg-n-brand/10 mb-6"
    >
      <Icon icon="i-lucide-users" class="size-8 text-n-brand" />
    </div>
    <h1 class="text-2xl font-bold text-n-slate-12 mb-2">
      {{ t('ONBOARDING.INVITE_STEP.TITLE') }}
    </h1>
    <p class="text-sm text-n-slate-10 mb-6">
      {{ t('ONBOARDING.INVITE_STEP.SUBTITLE') }}
    </p>

    <div class="w-full max-w-sm">
      <label class="text-sm font-medium text-n-slate-11 mb-1.5 block text-left">
        {{ t('ONBOARDING.INVITE_STEP.EMAILS_LABEL') }}
      </label>
      <div
        class="flex flex-wrap gap-1.5 rounded-lg border border-n-weak bg-white dark:bg-n-solid-3 px-2 py-2 min-h-[42px] focus-within:border-n-brand focus-within:ring-1 focus-within:ring-n-brand"
      >
        <span
          v-for="email in emails"
          :key="email"
          class="inline-flex items-center gap-1 rounded-md bg-n-alpha-2 px-2 py-0.5 text-xs text-n-slate-12"
        >
          {{ email }}
          <button
            class="text-n-slate-9 hover:text-n-slate-12"
            @click="removeEmail(email)"
          >
            <Icon icon="i-lucide-x" class="size-3" />
          </button>
        </span>
        <input
          v-model="emailInput"
          type="email"
          :placeholder="
            emails.length ? '' : t('ONBOARDING.INVITE_STEP.EMAILS_PLACEHOLDER')
          "
          class="flex-1 min-w-[120px] border-none bg-transparent p-0 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-8"
          @keydown="handleKeydown"
          @blur="addEmail"
        />
      </div>

      <!-- Existing agents -->
      <div v-if="agents.length > 1" class="mt-4 text-left">
        <p class="text-xs font-medium text-n-slate-9 mb-2">
          {{ t('ONBOARDING.INVITE_STEP.INVITED_AGENTS') }}
        </p>
        <div class="flex flex-wrap gap-1.5">
          <span
            v-for="agent in agents"
            :key="agent.id"
            class="inline-flex items-center gap-1 rounded-md bg-n-alpha-1 px-2 py-0.5 text-xs text-n-slate-10"
          >
            <Icon icon="i-lucide-user" class="size-3" />
            {{ agent.name || agent.email }}
          </span>
        </div>
      </div>

      <div
        v-if="lastError"
        class="flex items-center gap-2 rounded-lg bg-red-50 dark:bg-red-900/20 px-4 py-3 text-sm text-red-600 dark:text-red-400 mt-4"
      >
        <Icon icon="i-lucide-alert-circle" class="size-4 shrink-0" />
        <span class="flex-1">{{ lastError }}</span>
        <button
          class="text-xs underline hover:no-underline"
          @click="emit('retry')"
        >
          {{ t('ONBOARDING.RETRY') }}
        </button>
      </div>

      <NextButton
        class="mt-6 w-full"
        :label="isSaving ? t('ONBOARDING.SAVING') : t('ONBOARDING.NEXT')"
        :is-loading="isSaving"
        @click="proceed"
      />
    </div>
  </div>
</template>
