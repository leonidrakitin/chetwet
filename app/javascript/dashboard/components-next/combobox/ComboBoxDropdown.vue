<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  open: {
    type: Boolean,
    required: true,
  },
  options: {
    type: Array,
    required: true,
  },
  searchPlaceholder: {
    type: String,
    default: '',
  },
  emptyState: {
    type: String,
    default: '',
  },
  multiple: {
    type: Boolean,
    default: false,
  },
  selectedValues: {
    type: [String, Number, Array],
    default: () => [],
  },
});

const emit = defineEmits(['select', 'search']);

const { t } = useI18n();

const searchValue = defineModel('searchValue', {
  type: String,
  default: '',
});

const searchInput = ref(null);

const isSelected = option => {
  if (Array.isArray(props.selectedValues)) {
    return props.selectedValues.includes(option.value);
  }
  return option.value === props.selectedValues;
};

const onInputSearch = event => {
  searchValue.value = event.target.value;
  emit('search', event.target.value);
};

defineExpose({
  focus: () => searchInput.value?.focus(),
});
</script>

<template>
  <div
    v-show="open"
    class="absolute z-50 w-full mt-2 transition-opacity duration-200 border border-n-border-glass rounded-card shadow-glass-soft bg-n-glass-pane backdrop-blur-glass-card backdrop-saturate-glass overflow-hidden"
  >
    <div class="relative border-b border-n-border-glass-soft">
      <span
        class="absolute i-lucide-search top-3 size-4 left-3 text-n-text-body"
      />
      <input
        ref="searchInput"
        :value="searchValue"
        type="search"
        :placeholder="searchPlaceholder || t('COMBOBOX.SEARCH_PLACEHOLDER')"
        class="reset-base w-full py-2.5 pl-10 pr-2 text-sm focus:outline-none border-none bg-transparent text-n-text-display placeholder:text-n-text-body/60"
        @input="onInputSearch"
      />
    </div>
    <ul
      class="py-2 mb-0 overflow-auto max-h-60 px-2"
      role="listbox"
      :aria-multiselectable="multiple"
    >
      <li
        v-for="(option, index) in options"
        :key="`${option.value}-${index}`"
        class="flex items-center justify-between w-full gap-2 px-3 py-2 text-sm transition-colors duration-150 cursor-pointer rounded-pill hover:bg-n-glass-soft"
        :class="{
          'bg-n-glass-strong': isSelected(option),
        }"
        role="option"
        :aria-selected="isSelected(option)"
        @click="emit('select', option)"
      >
        <span
          :class="{
            'font-medium': isSelected(option),
          }"
          class="text-n-text-display"
        >
          {{ option.label }}
        </span>
        <span
          v-if="isSelected(option)"
          class="flex-shrink-0 i-lucide-check size-4 text-n-text-body"
        />
      </li>
      <li
        v-if="options.length === 0"
        class="px-3 py-2 text-sm text-n-text-body"
      >
        {{ emptyState || t('COMBOBOX.EMPTY_STATE') }}
      </li>
    </ul>
  </div>
</template>
