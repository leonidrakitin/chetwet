<script setup>
import { computed, watch } from 'vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
const props = defineProps({
  modelValue: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:modelValue']);

const messages = computed({
  get: () => {
    const p = props.modelValue;
    if (!Array.isArray(p) || p.length === 0) return [''];
    return [...p];
  },
  set: val => emit('update:modelValue', val),
});

watch(
  () => props.modelValue,
  p => {
    if ((!p || !Array.isArray(p) || p.length === 0) && messages.value.length) {
      emit('update:modelValue', ['']);
    }
  },
  { immediate: true }
);

function addMessage() {
  messages.value = [...messages.value, ''];
}

function removeMessage(index) {
  const next = messages.value.filter((_, i) => i !== index);
  messages.value = next.length ? next : [''];
}

function updateMessage(index, value) {
  const next = [...messages.value];
  next[index] = value ?? '';
  messages.value = next;
}

const previewSample = {
  'contact.name': 'Contact Name',
  'contact.first_name': 'First',
  'contact.last_name': 'Last',
  'contact.email': 'email@example.com',
  'contact.phone': '+1234567890',
  'contact.id': '1',
  'conversation.id': '1',
  'conversation.display_id': '#42',
  'conversation.contact_name': 'Customer',
  'agent.name': 'Agent Name',
  'agent.email': 'agent@example.com',
  'inbox.name': 'Inbox',
  'inbox.id': '1',
  'account.name': 'Account',
};

function previewText(text) {
  if (!text || typeof text !== 'string') return '';
  return text.replace(/\{\{([^}]+)\}\}/g, (match, variable) => {
    const key = variable.trim();
    return previewSample[key] ?? match;
  });
}

const firstMessagePreview = computed(() => {
  const first = messages.value[0];
  return previewText(first);
});
</script>

<template>
  <div class="flex flex-col gap-3 w-full mt-2">
    <div
      v-for="(msg, idx) in messages"
      :key="idx"
      class="flex flex-col gap-1 border border-solid rounded-lg p-2 border-n-strong bg-n-slate-2 dark:bg-n-solid-2"
    >
      <div class="flex items-center justify-between">
        <span class="text-xs text-n-slate-8 dark:text-n-slate-6">
          {{ $t('AUTOMATION.ACTION.MESSAGE_LABEL') }} {{ idx + 1 }}
        </span>
        <NextButton
          v-if="messages.length > 1"
          icon="i-lucide-trash-2"
          slate
          ghost
          class="flex-shrink-0"
          @click="removeMessage(idx)"
        />
      </div>
      <WootMessageEditor
        :model-value="msg"
        enable-variables
        rows="4"
        :placeholder="$t('AUTOMATION.ACTION.TEAM_MESSAGE_INPUT_PLACEHOLDER')"
        class="min-h-20"
        @update:model-value="updateMessage(idx, $event)"
      />
    </div>
    <NextButton
      icon="i-lucide-plus"
      blue
      faded
      sm
      :label="$t('AUTOMATION.ACTION.ADD_MESSAGE')"
      @click="addMessage"
    />
    <div
      v-if="firstMessagePreview"
      class="rounded-lg p-2 bg-n-slate-3 dark:bg-n-solid-3 border border-n-weak text-sm text-n-slate-8 dark:text-n-slate-6"
    >
      <span class="font-medium"
        >{{ $t('AUTOMATION.ACTION.PREVIEW_LABEL') }}:</span
      >
      <div class="mt-1 whitespace-pre-wrap break-words">
        {{ firstMessagePreview }}
      </div>
    </div>
  </div>
</template>
