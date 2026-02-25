<script setup>
import { useI18n } from 'vue-i18n';

const emit = defineEmits(['insert']);

const { t } = useI18n();

const VARIABLES = [
  {
    key: 'client_name',
    bgColor: '#dbeafe',
    textColor: '#1d4ed8',
    borderColor: '#bfdbfe',
  },
  {
    key: 'service_name',
    bgColor: '#ccfbf1',
    textColor: '#0f766e',
    borderColor: '#99f6e4',
  },
  {
    key: 'branch_name',
    bgColor: '#fef3c7',
    textColor: '#b45309',
    borderColor: '#fde68a',
  },
  {
    key: 'master_name',
    bgColor: '#ede9fe',
    textColor: '#7c3aed',
    borderColor: '#ddd6fe',
  },
  {
    key: 'price',
    bgColor: '#fee2e2',
    textColor: '#b91c1c',
    borderColor: '#fecaca',
  },
  {
    key: 'date',
    bgColor: '#ffedd5',
    textColor: '#c2410c',
    borderColor: '#fed7aa',
  },
  {
    key: 'time',
    bgColor: '#e2e8f0',
    textColor: '#334155',
    borderColor: '#cbd5e1',
  },
];

const toToken = key => '{' + key + '}';

const onDragStart = (event, key) => {
  event.dataTransfer.setData('text/plain', toToken(key));
  event.dataTransfer.effectAllowed = 'copy';
};
</script>

<template>
  <div class="flex flex-col gap-1.5">
    <label class="text-xs font-medium text-n-slate-10 uppercase tracking-wide">
      {{ t('NOTIFICATION_TEMPLATES.VARIABLES.LABEL') }}
    </label>
    <div class="flex flex-wrap gap-1.5">
      <button
        v-for="v in VARIABLES"
        :key="v.key"
        draggable="true"
        class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium cursor-grab border transition-opacity hover:opacity-80 active:opacity-60"
        :style="{
          backgroundColor: v.bgColor,
          color: v.textColor,
          borderColor: v.borderColor,
        }"
        @click="emit('insert', toToken(v.key))"
        @dragstart="onDragStart($event, v.key)"
      >
        {{ toToken(v.key) }}
      </button>
    </div>
  </div>
</template>
