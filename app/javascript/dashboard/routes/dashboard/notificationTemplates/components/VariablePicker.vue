<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { VARIABLE_KEYS, toToken } from '../constants/variables';

const emit = defineEmits(['insert']);

const { t } = useI18n();

const VARIABLE_CHIP_CLASSES = {
  client_name: 'bg-blue-100 text-blue-800 border-blue-200',
  service_name: 'bg-teal-100 text-teal-800 border-teal-200',
  branch_name: 'bg-amber-100 text-amber-800 border-amber-200',
  master_name: 'bg-violet-100 text-violet-800 border-violet-200',
  price: 'bg-red-100 text-red-800 border-red-200',
  date: 'bg-orange-100 text-orange-800 border-orange-200',
  time: 'bg-slate-200 text-slate-700 border-slate-300',
};

const VARIABLES = computed(() =>
  VARIABLE_KEYS.map(key => ({
    key,
    chipClass: VARIABLE_CHIP_CLASSES[key] ?? 'bg-slate-200 text-slate-700',
    label: t(`NOTIFICATION_TEMPLATES.VARIABLES.${key}`),
    description: t(`NOTIFICATION_TEMPLATES.VARIABLES.${key}_description`),
    example: t(`NOTIFICATION_TEMPLATES.VARIABLES.${key}_example`),
  }))
);

const onDragStart = (event, key) => {
  event.dataTransfer.setData('text/plain', toToken(key));
  event.dataTransfer.effectAllowed = 'copy';
};

const insert = k => emit('insert', toToken(k));
</script>

<template>
  <div class="flex flex-col gap-2">
    <label class="text-xs font-medium text-n-slate-10 uppercase tracking-wide">
      {{ t('NOTIFICATION_TEMPLATES.VARIABLES.LABEL') }}
    </label>
    <div class="flex flex-col gap-2">
      <div
        v-for="v in VARIABLES"
        :key="v.key"
        draggable="true"
        class="flex flex-col gap-1 rounded-lg border-l-4 border-n-weak bg-n-alpha-1 p-2 cursor-grab transition-colors hover:border-n-strong hover:bg-n-alpha-2 active:cursor-grabbing"
        :class="[
          v.key === 'client_name' && 'border-l-blue-300',
          v.key === 'service_name' && 'border-l-teal-300',
          v.key === 'branch_name' && 'border-l-amber-300',
          v.key === 'master_name' && 'border-l-violet-300',
          v.key === 'price' && 'border-l-red-300',
          v.key === 'date' && 'border-l-orange-300',
          v.key === 'time' && 'border-l-slate-400',
        ]"
        @click="insert(v.key)"
        @dragstart="onDragStart($event, v.key)"
      >
        <span
          class="inline-flex w-fit items-center rounded-full border px-2 py-0.5 text-xs font-medium"
          :class="v.chipClass"
        >
          {{ toToken(v.key) }}
        </span>
        <p class="text-xs text-n-slate-11">
          {{ v.description }}
        </p>
        <p class="text-xs text-n-slate-9 font-mono">
          {{ t('NOTIFICATION_TEMPLATES.VARIABLES.EXAMPLE_PREFIX') }}
          {{ v.example }}
        </p>
      </div>
    </div>
  </div>
</template>
