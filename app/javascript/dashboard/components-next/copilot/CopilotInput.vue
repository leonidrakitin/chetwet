<script setup>
import { ref, nextTick, onMounted } from 'vue';

const emit = defineEmits(['send']);
const message = ref('');
const textareaRef = ref(null);

const adjustHeight = () => {
  if (!textareaRef.value) return;

  // Reset height to auto to get the correct scrollHeight
  textareaRef.value.style.height = 'auto';
  // Set the height to the scrollHeight
  textareaRef.value.style.height = `${textareaRef.value.scrollHeight}px`;
};

const sendMessage = () => {
  if (message.value.trim()) {
    emit('send', message.value);
    message.value = '';
    // Reset textarea height after sending
    nextTick(() => {
      adjustHeight();
    });
  }
};

const handleInput = () => {
  nextTick(adjustHeight);
};

const handleEnterKey = event => {
  if (event.isComposing) return;
  event.preventDefault();
  sendMessage();
};

onMounted(() => {
  nextTick(adjustHeight);
});
</script>

<template>
  <form class="relative min-w-0 w-full" @submit.prevent="sendMessage">
    <textarea
      ref="textareaRef"
      v-model="message"
      :placeholder="$t('CAPTAIN.COPILOT.SEND_MESSAGE')"
      class="w-full min-w-0 reset-base bg-n-solid-1 dark:bg-n-solid-2 ltr:pl-3.5 ltr:pr-11 rtl:pl-11 rtl:pr-3.5 py-2.5 text-sm border border-n-border-glass rounded-xl shadow-inset-hairline focus:outline-none focus:ring-2 focus:ring-n-blue-11/25 focus:border-n-blue-11 resize-none overflow-y-auto max-h-[200px] mb-0 text-n-text-display placeholder:text-n-text-body/50"
      rows="1"
      @input="handleInput"
      @keydown.enter.exact="handleEnterKey"
    />
    <button
      class="absolute ltr:right-2 rtl:left-2 top-1/2 -translate-y-1/2 h-8 w-9 flex items-center justify-center rounded-lg text-n-text-body bg-n-alpha-2 hover:bg-n-alpha-3 hover:text-n-blue-11 transition-colors"
      type="submit"
    >
      <i class="i-ph-arrow-up size-5" />
    </button>
  </form>
</template>
