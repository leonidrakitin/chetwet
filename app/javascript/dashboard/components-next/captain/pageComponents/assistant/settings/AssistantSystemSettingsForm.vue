<script setup>
import { reactive, computed, watch, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { storeToRefs } from 'pinia';
import { useVuelidate } from '@vuelidate/core';
import { minLength } from '@vuelidate/validators';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { useCaptainConfigStore } from 'dashboard/store/captain/preferences';

import Button from 'dashboard/components-next/button/Button.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const { isCloudFeatureEnabled } = useAccount();

const captainConfigStore = useCaptainConfigStore();
const { messageBufferSeconds } = storeToRefs(captainConfigStore);
const bufferSecondsInput = ref(4);
watch(
  messageBufferSeconds,
  val => {
    bufferSecondsInput.value = val;
  },
  { immediate: true }
);

function clampBufferSeconds(value) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.min(30, Math.max(1, Math.round(n))) : 4;
}

async function handleMessageBufferChange(value) {
  const seconds = clampBufferSeconds(value);
  try {
    await captainConfigStore.updatePreferences({
      message_buffer_seconds: seconds,
    });
    useAlert(t('CAPTAIN_SETTINGS.API.SUCCESS'));
  } catch {
    useAlert(t('CAPTAIN_SETTINGS.API.ERROR'));
    captainConfigStore.fetch();
  }
}

const isCaptainV2Enabled = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.CAPTAIN_V2)
);

const initialState = {
  handoffMessage: '',
  resolutionMessage: '',
  instructions: '',
  temperature: 1,
  handoffApprovalEnabled: true,
  handoffApprovalInstructions: '',
  knowledgeMode: 'balanced',
};

const state = reactive({ ...initialState });

const validationRules = {
  handoffMessage: { minLength: minLength(1) },
  resolutionMessage: { minLength: minLength(1) },
  instructions: { minLength: minLength(1) },
};

const v$ = useVuelidate(validationRules, state);

const getErrorMessage = field => {
  return v$.value[field].$error ? v$.value[field].$errors[0].$message : '';
};

const formErrors = computed(() => ({
  handoffMessage: getErrorMessage('handoffMessage'),
  resolutionMessage: getErrorMessage('resolutionMessage'),
  instructions: getErrorMessage('instructions'),
}));

const updateStateFromAssistant = assistant => {
  const config = assistant.config || {};
  // API may return null for unset JSON keys; Editor breaks on null (modelValue.length).
  state.handoffMessage = config.handoff_message ?? '';
  state.resolutionMessage = config.resolution_message ?? '';
  state.instructions = config.instructions ?? '';
  state.temperature = config.temperature || 1;
  state.handoffApprovalEnabled = config.handoff_approval_enabled !== false;
  state.handoffApprovalInstructions =
    config.handoff_approval_instructions ?? '';
  state.knowledgeMode = config.knowledge_mode || 'balanced';
};

const handleSystemMessagesUpdate = async () => {
  const validations = [
    v$.value.handoffMessage.$validate(),
    v$.value.resolutionMessage.$validate(),
  ];

  if (!isCaptainV2Enabled.value) {
    validations.push(v$.value.instructions.$validate());
  }

  const result = await Promise.all(validations).then(results =>
    results.every(Boolean)
  );
  if (!result) return;

  const payload = {
    config: {
      ...(props.assistant.config || {}),
      handoff_message: state.handoffMessage,
      resolution_message: state.resolutionMessage,
      temperature: state.temperature || 1,
      handoff_approval_enabled: state.handoffApprovalEnabled,
      handoff_approval_instructions: state.handoffApprovalInstructions,
      knowledge_mode: state.knowledgeMode,
    },
  };

  if (!isCaptainV2Enabled.value) {
    payload.config.instructions = state.instructions;
  }

  emit('submit', payload);
};

onMounted(() => {
  captainConfigStore.fetch();
});

watch(
  () => props.assistant,
  newAssistant => {
    if (newAssistant) updateStateFromAssistant(newAssistant);
  },
  { immediate: true }
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-1 gap-6">
      <Editor
        v-model="state.handoffMessage"
        :label="t('CAPTAIN.ASSISTANTS.FORM.HANDOFF_MESSAGE.LABEL')"
        :placeholder="t('CAPTAIN.ASSISTANTS.FORM.HANDOFF_MESSAGE.PLACEHOLDER')"
        :message="formErrors.handoffMessage"
        :message-type="formErrors.handoffMessage ? 'error' : 'info'"
        class="z-0"
      />

      <Editor
        v-model="state.resolutionMessage"
        :label="t('CAPTAIN.ASSISTANTS.FORM.RESOLUTION_MESSAGE.LABEL')"
        :placeholder="
          t('CAPTAIN.ASSISTANTS.FORM.RESOLUTION_MESSAGE.PLACEHOLDER')
        "
        :message="formErrors.resolutionMessage"
        :message-type="formErrors.resolutionMessage ? 'error' : 'info'"
        class="z-0"
      />
    </div>

    <Editor
      v-if="!isCaptainV2Enabled"
      v-model="state.instructions"
      :label="t('CAPTAIN.ASSISTANTS.FORM.INSTRUCTIONS.LABEL')"
      :placeholder="t('CAPTAIN.ASSISTANTS.FORM.INSTRUCTIONS.PLACEHOLDER')"
      :message="formErrors.instructions"
      :max-length="20000"
      :message-type="formErrors.instructions ? 'error' : 'info'"
      class="z-0"
    />

    <div class="grid grid-cols-1 gap-6 md:grid-cols-3 md:gap-8">
      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN.ASSISTANTS.FORM.TEMPERATURE.LABEL') }}
        </label>
        <div class="flex items-center gap-4">
          <input
            v-model="state.temperature"
            type="range"
            min="0"
            max="1"
            step="0.1"
            class="w-full"
          />
          <span class="text-sm text-n-slate-12">{{ state.temperature }}</span>
        </div>
        <p class="text-sm text-n-slate-11 italic">
          {{ t('CAPTAIN.ASSISTANTS.FORM.TEMPERATURE.DESCRIPTION') }}
        </p>
      </div>

      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN.ASSISTANTS.FORM.MESSAGE_BUFFER.LABEL') }}
        </label>
        <div class="flex items-center gap-4">
          <input
            v-model.number="bufferSecondsInput"
            type="range"
            min="1"
            max="30"
            step="1"
            class="w-full h-2 rounded-lg appearance-none cursor-pointer bg-n-weak accent-n-blue-11"
            @change="handleMessageBufferChange(bufferSecondsInput)"
          />
          <span class="text-sm font-medium text-n-slate-12 shrink-0 w-10">
            {{
              t('CAPTAIN.ASSISTANTS.FORM.MESSAGE_BUFFER.SECONDS', {
                count: bufferSecondsInput,
              })
            }}
          </span>
        </div>
        <p class="text-sm text-n-slate-11 italic">
          {{ t('CAPTAIN.ASSISTANTS.FORM.MESSAGE_BUFFER.DESCRIPTION') }}
        </p>
      </div>

      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN.ASSISTANTS.FORM.KNOWLEDGE_MODE.LABEL') }}
        </label>
        <select
          v-model="state.knowledgeMode"
          class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 focus:border-n-blue-11 focus:outline-none"
        >
          <option value="balanced">
            {{ t('CAPTAIN.ASSISTANTS.FORM.KNOWLEDGE_MODE.OPTIONS.BALANCED') }}
          </option>
          <option value="strict">
            {{ t('CAPTAIN.ASSISTANTS.FORM.KNOWLEDGE_MODE.OPTIONS.STRICT') }}
          </option>
          <option value="ultra_strict">
            {{
              t('CAPTAIN.ASSISTANTS.FORM.KNOWLEDGE_MODE.OPTIONS.ULTRA_STRICT')
            }}
          </option>
        </select>
        <p class="text-sm text-n-slate-11 italic">
          {{ t('CAPTAIN.ASSISTANTS.FORM.KNOWLEDGE_MODE.DESCRIPTION') }}
        </p>
      </div>
    </div>

    <div class="flex flex-col gap-3 relative z-10">
      <div class="flex items-start gap-3">
        <Switch v-model="state.handoffApprovalEnabled" />
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.ASSISTANTS.FORM.HANDOFF_APPROVAL.LABEL') }}
          </label>
          <p class="text-sm text-n-slate-11 italic">
            {{ t('CAPTAIN.ASSISTANTS.FORM.HANDOFF_APPROVAL.DESCRIPTION') }}
          </p>
        </div>
      </div>
      <Editor
        v-if="state.handoffApprovalEnabled"
        v-model="state.handoffApprovalInstructions"
        :label="
          t('CAPTAIN.ASSISTANTS.FORM.HANDOFF_APPROVAL.INSTRUCTIONS_LABEL')
        "
        :placeholder="
          t('CAPTAIN.ASSISTANTS.FORM.HANDOFF_APPROVAL.INSTRUCTIONS_PLACEHOLDER')
        "
        :max-length="4000"
        class="z-0"
      />
    </div>

    <div>
      <Button
        :label="t('CAPTAIN.ASSISTANTS.FORM.UPDATE')"
        @click="handleSystemMessagesUpdate"
      />
    </div>
  </div>
</template>
