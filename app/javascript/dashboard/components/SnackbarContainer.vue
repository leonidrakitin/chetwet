<script setup>
import { ref, onMounted, onUnmounted, nextTick } from 'vue';
import WootSnackbar from './Snackbar.vue';
import { emitter } from 'shared/helpers/mitt';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  duration: {
    type: Number,
    default: 3000,
  },
});

const { t } = useI18n();

const snackMessages = ref([]);
const snackbarContainer = ref(null);

const showPopover = () => {
  try {
    const el = snackbarContainer.value;
    if (el?.matches(':popover-open')) {
      el.hidePopover();
    }
    el?.showPopover();
  } catch (e) {
    // ignore
  }
};

const dismissMessage = key => {
  snackMessages.value = snackMessages.value.filter(m => m.key !== key);
};

const onNewToastMessage = ({ message: originalMessage, action }) => {
  const message = action?.usei18n ? t(originalMessage) : originalMessage;
  const duration = action?.duration || props.duration;
  const key = Date.now() + Math.random();

  snackMessages.value.push({
    key,
    message,
    action,
    duration,
  });

  nextTick(showPopover);

  setTimeout(() => {
    dismissMessage(key);
  }, duration);
};

onMounted(() => {
  emitter.on('newToastMessage', onNewToastMessage);
});

onUnmounted(() => {
  emitter.off('newToastMessage', onNewToastMessage);
});
</script>

<template>
  <div
    ref="snackbarContainer"
    popover="manual"
    class="fixed right-6 top-6 z-[9999] m-0 flex w-[22rem] flex-col gap-2 border-0 bg-transparent p-0 outline-none"
  >
    <transition-group name="toast" tag="div" class="flex flex-col gap-2">
      <WootSnackbar
        v-for="snackMessage in snackMessages"
        :key="snackMessage.key"
        :message="snackMessage.message"
        :action="snackMessage.action"
        :duration="snackMessage.duration"
        @dismiss="dismissMessage(snackMessage.key)"
      />
    </transition-group>
  </div>
</template>
