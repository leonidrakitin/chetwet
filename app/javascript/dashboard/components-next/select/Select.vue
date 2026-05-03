<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  options: {
    type: Array,
    default: () => [],
    validator: options =>
      options.every(
        opt => typeof opt === 'object' && 'value' in opt && 'label' in opt
      ),
  },
  groups: {
    type: Array,
    default: () => [],
    validator: groups =>
      groups.every(
        group =>
          'label' in group &&
          Array.isArray(group.options) &&
          group.options.every(opt => 'value' in opt && 'label' in opt)
      ),
  },
  placeholder: {
    type: String,
    default: '',
  },
  disabled: {
    type: Boolean,
    default: false,
  },
  error: {
    type: String,
    default: '',
  },
});

const modelValue = defineModel({
  type: [String, Number, Boolean],
  default: '',
});
</script>

<template>
  <div class="w-fit relative">
    <select
      v-model="modelValue"
      :disabled="disabled"
      class="appearance-none bg-none rounded-pill border-0 outline-1 outline -outline-offset-1 transition-all duration-200 bg-n-glass-soft backdrop-blur-glass-rail backdrop-saturate-glass shadow-inset-hairline !mb-0 h-9 py-2 px-4 pr-10 text-sm text-n-text-display"
      :class="{
        'outline-n-border-glass-soft hover:outline-n-border-glass focus:outline-n-accent-active':
          !error && !disabled,
        'outline-n-ruby-9 focus:outline-n-ruby-9': error && !disabled,
        'outline-n-border-glass-soft bg-n-glass-soft cursor-not-allowed opacity-60':
          disabled,
      }"
    >
      <option v-if="placeholder" value="" disabled>
        {{ placeholder }}
      </option>
      <template v-if="groups.length">
        <optgroup
          v-for="group in groups"
          :key="group.label"
          :label="group.label"
        >
          <option
            v-for="option in group.options"
            :key="option.value"
            :value="option.value"
            :disabled="option.disabled"
          >
            {{ option.label }}
          </option>
        </optgroup>
      </template>
      <template v-else>
        <option
          v-for="option in options"
          :key="option.value"
          :value="option.value"
          :disabled="option.disabled"
        >
          {{ option.label }}
        </option>
      </template>
    </select>
    <div
      class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none"
    >
      <Icon
        icon="i-lucide-chevron-down"
        class="size-4 text-n-text-body"
        :class="{ 'opacity-50': disabled }"
      />
    </div>
  </div>
</template>
