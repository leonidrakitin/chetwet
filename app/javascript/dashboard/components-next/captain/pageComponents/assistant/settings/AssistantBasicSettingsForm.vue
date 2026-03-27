<script setup>
import { reactive, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const TONE_OPTIONS = ['formal', 'neutral', 'friendly'];

const initialState = {
  name: '',
  description: '',
  productName: '',
  tone: 'neutral',
  emojify: false,
};

const state = reactive({ ...initialState });

const validationRules = {
  name: { required, minLength: minLength(1) },
  description: { required, minLength: minLength(1) },
  productName: { required, minLength: minLength(1) },
};

const v$ = useVuelidate(validationRules, state);

const getErrorMessage = field => {
  return v$.value[field].$error ? v$.value[field].$errors[0].$message : '';
};

const formErrors = computed(() => ({
  name: getErrorMessage('name'),
  description: getErrorMessage('description'),
  productName: getErrorMessage('productName'),
}));

const updateStateFromAssistant = assistant => {
  const { config = {} } = assistant;
  state.name = assistant.name;
  state.description = assistant.description;
  state.productName = config.product_name;
  state.tone = config.tone || 'neutral';
  state.emojify = config.emojify || false;
};

const handleBasicInfoUpdate = async () => {
  const result = await Promise.all([
    v$.value.name.$validate(),
    v$.value.description.$validate(),
    v$.value.productName.$validate(),
  ]).then(results => results.every(Boolean));
  if (!result) return;

  const payload = {
    name: state.name,
    description: state.description,
    config: {
      ...props.assistant.config,
      product_name: state.productName,
      tone: state.tone,
      emojify: state.emojify,
    },
  };

  emit('submit', payload);
};

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
    <Input
      v-model="state.name"
      :label="t('CAPTAIN.ASSISTANTS.FORM.NAME.LABEL')"
      :placeholder="t('CAPTAIN.ASSISTANTS.FORM.NAME.PLACEHOLDER')"
      :message="formErrors.name"
      :message-type="formErrors.name ? 'error' : 'info'"
    />

    <Input
      v-model="state.productName"
      :label="t('CAPTAIN.ASSISTANTS.FORM.PRODUCT_NAME.LABEL')"
      :placeholder="t('CAPTAIN.ASSISTANTS.FORM.PRODUCT_NAME.PLACEHOLDER')"
      :message="formErrors.productName"
      :message-type="formErrors.productName ? 'error' : 'info'"
    />

    <Editor
      v-model="state.description"
      :label="t('CAPTAIN.ASSISTANTS.FORM.DESCRIPTION.LABEL')"
      :placeholder="t('CAPTAIN.ASSISTANTS.FORM.DESCRIPTION.PLACEHOLDER')"
      :message="formErrors.description"
      :message-type="formErrors.description ? 'error' : 'info'"
      class="z-0"
    />

    <div class="flex flex-col gap-3">
      <label class="text-sm font-medium text-n-slate-12">
        {{ t('CAPTAIN.ASSISTANTS.FORM.TONE.LABEL') }}
      </label>
      <div class="flex flex-wrap gap-2">
        <button
          v-for="option in TONE_OPTIONS"
          :key="option"
          type="button"
          class="px-4 py-1.5 rounded-lg text-sm font-medium border transition-colors"
          :class="
            state.tone === option
              ? 'bg-n-brand border-n-brand text-white'
              : 'bg-transparent border-n-weak text-n-slate-11 hover:border-n-slate-8'
          "
          @click="state.tone = option"
        >
          {{
            t(`CAPTAIN.ASSISTANTS.FORM.TONE.OPTIONS.${option.toUpperCase()}`)
          }}
        </button>
      </div>
      <div
        class="flex items-start gap-2.5 rounded-xl bg-n-alpha-1 border border-n-weak px-4 py-3"
      >
        <span
          class="i-lucide-message-circle shrink-0 mt-0.5 size-4 text-n-slate-9"
        />
        <p class="text-sm text-n-slate-11 italic leading-relaxed">
          {{
            t(
              `CAPTAIN.ASSISTANTS.FORM.TONE.EXAMPLES.${state.tone.toUpperCase()}`
            )
          }}
        </p>
      </div>
    </div>

    <div class="flex flex-col gap-3">
      <label class="flex items-center gap-3 cursor-pointer select-none">
        <input
          v-model="state.emojify"
          type="checkbox"
          class="w-4 h-4 rounded accent-n-brand cursor-pointer"
        />
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN.ASSISTANTS.FORM.EMOJIFY.LABEL') }}
        </span>
      </label>
      <p class="text-sm text-n-slate-11 italic pl-7">
        {{ t('CAPTAIN.ASSISTANTS.FORM.EMOJIFY.DESCRIPTION') }}
      </p>
      <div class="flex flex-col gap-1.5 pl-7">
        <div
          class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm transition-colors"
          :class="
            !state.emojify
              ? 'bg-n-alpha-1 border border-n-weak text-n-slate-12 font-medium'
              : 'text-n-slate-9'
          "
        >
          <span class="i-lucide-x shrink-0 size-3.5 text-n-slate-9" />
          {{ t('CAPTAIN.ASSISTANTS.FORM.EMOJIFY.EXAMPLE_OFF') }}
        </div>
        <div
          class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm transition-colors"
          :class="
            state.emojify
              ? 'bg-n-alpha-1 border border-n-weak text-n-slate-12 font-medium'
              : 'text-n-slate-9'
          "
        >
          <span class="i-lucide-check shrink-0 size-3.5 text-n-teal-10" />
          {{ t('CAPTAIN.ASSISTANTS.FORM.EMOJIFY.EXAMPLE_ON') }}
        </div>
      </div>
    </div>

    <div>
      <Button
        :label="t('CAPTAIN.ASSISTANTS.FORM.UPDATE')"
        @click="handleBasicInfoUpdate"
      />
    </div>
  </div>
</template>
