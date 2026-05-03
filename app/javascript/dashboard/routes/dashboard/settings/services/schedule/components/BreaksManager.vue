<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const breaks = computed({
  get: () => props.modelValue,
  set: value => emit('update:modelValue', value),
});

const addBreak = () => {
  breaks.value = [...breaks.value, { start: '12:00', end: '13:00' }];
};

const removeBreak = index => {
  breaks.value = breaks.value.filter((_, i) => i !== index);
};

const updateBreak = (index, field, value) => {
  breaks.value = breaks.value.map((brk, i) =>
    i === index ? { ...brk, [field]: value } : brk
  );
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <div class="flex items-center justify-between">
      <label class="text-sm font-medium text-n-text-display">
        {{ t('SCHEDULE.SETTINGS.BREAKS') }}
      </label>
      <Button
        icon="i-lucide-plus"
        :label="t('SCHEDULE.SETTINGS.ADD_BREAK')"
        faded
        slate
        xs
        @click="addBreak"
      />
    </div>

    <div
      v-if="breaks.length"
      class="flex flex-col gap-2 border border-n-border-glass-soft rounded-lg p-3"
    >
      <div
        v-for="(brk, index) in breaks"
        :key="index"
        class="flex items-center gap-2"
      >
        <input
          type="time"
          :value="brk.start"
          class="px-2 py-1 text-sm border border-n-border-glass-soft rounded-md bg-n-glass-soft text-n-text-display focus:outline-none focus:ring-2 focus:ring-n-brand"
          @change="updateBreak(index, 'start', $event.target.value)"
        />
        <span class="text-n-text-body/60">—</span>
        <input
          type="time"
          :value="brk.end"
          class="px-2 py-1 text-sm border border-n-border-glass-soft rounded-md bg-n-glass-soft text-n-text-display focus:outline-none focus:ring-2 focus:ring-n-brand"
          @change="updateBreak(index, 'end', $event.target.value)"
        />
        <Button icon="i-lucide-x" slate xs @click="removeBreak(index)" />
      </div>
    </div>

    <p v-else class="text-sm text-n-text-body/60">
      {{ t('SCHEDULE.SETTINGS.NO_BREAKS') }}
    </p>
  </div>
</template>
