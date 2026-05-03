<script setup>
import { ref, computed } from 'vue';
import { onClickOutside } from '@vueuse/core';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';

const props = defineProps({
  type: {
    type: String,
    default: 'edit',
    validator: value => ['alert', 'edit'].includes(value),
  },
  title: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
  cancelButtonLabel: {
    type: String,
    default: '',
  },
  confirmButtonLabel: {
    type: String,
    default: '',
  },
  disableConfirmButton: {
    type: Boolean,
    default: false,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  showCancelButton: {
    type: Boolean,
    default: true,
  },
  showConfirmButton: {
    type: Boolean,
    default: true,
  },
  overflowYAuto: {
    type: Boolean,
    default: false,
  },
  width: {
    type: String,
    default: 'lg',
    validator: value =>
      ['6xl', '5xl', '4xl', '3xl', '2xl', 'xl', 'lg', 'md', 'sm'].includes(
        value
      ),
  },
  maxHeight: {
    type: String,
    default: '',
  },
  position: {
    type: String,
    default: 'center',
    validator: value => ['center', 'top'].includes(value),
  },
});

const emit = defineEmits(['confirm', 'close']);

const { t } = useI18n();

const dialogRef = ref(null);
const dialogContentRef = ref(null);
const isOpen = ref(false);

const maxWidthClass = computed(() => {
  const classesMap = {
    '6xl': 'max-w-6xl',
    '5xl': 'max-w-5xl',
    '4xl': 'max-w-4xl',
    '3xl': 'max-w-3xl',
    '2xl': 'max-w-2xl',
    xl: 'max-w-xl',
    lg: 'max-w-lg',
    md: 'max-w-md',
    sm: 'max-w-sm',
  };

  return classesMap[props.width] ?? 'max-w-md';
});

const positionClass = computed(() => {
  if (props.position === 'top') return 'dialog-position-top';
  if (props.position === 'center') return 'dialog-position-center';

  return '';
});

const open = () => {
  isOpen.value = true;
  dialogRef.value?.showModal();
};

const close = () => {
  if (!isOpen.value) return;
  isOpen.value = false;
  dialogRef.value?.close();
  emit('close');
};

// Sync Vue state when the native dialog closes (Esc, programmatic close(), etc.).
// Skip if we already cleared isOpen in close() to avoid double emit.
const handleDialogClose = e => {
  if (e.target !== dialogRef.value) return;
  if (!isOpen.value) return;
  isOpen.value = false;
  emit('close');
};

// Only close on click-outside if this dialog is the topmost one.
// If another dialog (e.g. ProseMirror prompt) is open on top, ignore.
const handleClickOutside = () => {
  const dialogs = document.querySelectorAll('dialog[open]');
  if (dialogs[dialogs.length - 1] === dialogRef.value) close();
};

onClickOutside(dialogContentRef, () => {
  handleClickOutside();
});

const confirm = () => {
  emit('confirm');
};

defineExpose({ open, close });
</script>

<template>
  <TeleportWithDirection to="body">
    <dialog
      ref="dialogRef"
      class="w-full transition-all duration-300 ease-in-out shadow-glass-deep rounded-card"
      :class="[
        maxWidthClass,
        positionClass,
        overflowYAuto ? 'overflow-y-auto' : 'overflow-visible',
        maxHeight && !overflowYAuto
          ? 'flex flex-col min-h-0 overflow-hidden'
          : '',
      ]"
      :style="maxHeight ? { maxHeight } : undefined"
      @close="handleDialogClose"
    >
      <form
        ref="dialogContentRef"
        class="flex flex-col w-full gap-6 p-6 text-start align-middle transition-all duration-300 ease-in-out transform bg-n-glass-pane backdrop-blur-glass-card backdrop-saturate-glass border border-n-border-glass shadow-glass-deep rounded-card min-h-0"
        :class="
          maxHeight
            ? 'flex-1 min-h-0 min-w-0 overflow-x-visible overflow-y-hidden'
            : 'h-auto min-w-0 overflow-visible'
        "
        @submit.prevent="confirm"
        @click.stop
      >
        <div
          v-if="title || description"
          class="flex flex-col gap-2 flex-shrink-0"
        >
          <h3 class="text-base font-medium leading-6 text-n-text-display">
            {{ title }}
          </h3>
          <slot name="description">
            <p v-if="description" class="mb-0 text-sm text-n-text-body">
              {{ description }}
            </p>
          </slot>
        </div>
        <div
          v-if="isOpen"
          class="flex flex-col min-h-0 min-w-0 px-2 py-1.5"
          :class="
            maxHeight
              ? 'flex-1 overflow-y-auto overflow-x-hidden overscroll-y-contain'
              : ''
          "
        >
          <slot />
        </div>
        <div class="flex-shrink-0">
          <slot name="footer">
            <div
              v-if="showCancelButton || showConfirmButton"
              class="flex items-center justify-between w-full gap-3"
            >
              <Button
                v-if="showCancelButton"
                variant="faded"
                color="slate"
                :label="cancelButtonLabel || t('DIALOG.BUTTONS.CANCEL')"
                class="w-full"
                type="button"
                @click="close"
              />
              <Button
                v-if="showConfirmButton"
                :color="type === 'edit' ? 'blue' : 'ruby'"
                :label="confirmButtonLabel || t('DIALOG.BUTTONS.CONFIRM')"
                class="w-full"
                :is-loading="isLoading"
                :disabled="disableConfirmButton || isLoading"
                type="submit"
              />
            </div>
          </slot>
        </div>
      </form>
    </dialog>
  </TeleportWithDirection>
</template>

<style scoped>
dialog::backdrop {
  @apply bg-n-alpha-black1 backdrop-blur-[4px];
}

.dialog-position-top {
  margin-top: clamp(2rem, 5vh, 5rem);
  margin-bottom: auto;
}

.dialog-position-center {
  /* HTML <dialog> default positioning is inconsistent across browsers.
   * We explicitly center to make modal placement stable. */
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  margin: 0;
}
</style>
