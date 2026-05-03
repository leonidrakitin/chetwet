<script setup>
import { useI18n } from 'vue-i18n';

const props = defineProps({
  disabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['change']);

const { t } = useI18n();

const modelValue = defineModel({
  type: Boolean,
  default: false,
});

const updateValue = () => {
  if (props.disabled) return;
  modelValue.value = !modelValue.value;
  emit('change', !modelValue.value);
};
</script>

<template>
  <button
    type="button"
    class="group relative h-4 rounded-full w-7 flex-shrink-0 select-none border focus:outline-none focus:ring-1 focus:ring-n-accent-active focus:ring-offset-n-slate-2 focus:ring-offset-2 transition-colors duration-200 ease-in-out disabled:opacity-60 disabled:cursor-not-allowed"
    :class="
      modelValue
        ? 'bg-n-accent-active border-n-accent-active shadow-pill-active'
        : 'bg-n-glass-soft border-n-border-glass-soft shadow-inset-hairline'
    "
    role="switch"
    :disabled="disabled"
    :aria-checked="modelValue"
    @click="updateValue"
  >
    <span class="sr-only">{{ t('SWITCH.TOGGLE') }}</span>
    <span
      class="absolute top-1/2 ltr:left-0.5 rtl:right-0.5 -translate-y-1/2 transition-transform duration-[350ms] ease-[cubic-bezier(0.34,1.56,0.64,1)]"
      :class="
        modelValue
          ? 'ltr:translate-x-3 rtl:-translate-x-3 group-active:ltr:translate-x-[6px] rtl:group-active:-translate-x-[6px]'
          : 'ltr:translate-x-0 rtl:translate-x-0'
      "
    >
      <span
        class="block h-3 w-3 rounded-full transition-[width] duration-[180ms] ease-in-out group-active:w-[18px]"
        :class="
          modelValue
            ? 'bg-n-accent-active-fg shadow-md'
            : 'bg-n-text-display/80 shadow-sm'
        "
      />
    </span>
  </button>
</template>
