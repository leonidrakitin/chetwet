<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  labels: { type: Array, default: () => [] },
  placeholder: { type: String, default: '' },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const open = ref(false);
const search = ref('');
const containerRef = ref(null);

const filteredLabels = computed(() => {
  const q = search.value.trim().toLowerCase();
  if (!q) return props.labels;
  return props.labels.filter(label => label.title.toLowerCase().includes(q));
});

const isSelected = title => props.modelValue.includes(title);

const toggle = title => {
  const current = [...props.modelValue];
  const idx = current.indexOf(title);
  if (idx >= 0) {
    current.splice(idx, 1);
  } else {
    current.push(title);
  }
  emit('update:modelValue', current);
};

const remove = title => {
  emit(
    'update:modelValue',
    props.modelValue.filter(item => item !== title)
  );
};

const handleBlur = e => {
  if (containerRef.value?.contains(e.relatedTarget)) return;
  open.value = false;
};
</script>

<template>
  <div ref="containerRef" class="relative" @focusout="handleBlur">
    <div
      class="flex flex-wrap items-center gap-1 min-h-[2.5rem] w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-2 py-1 cursor-pointer"
      @click="open = !open"
    >
      <span
        v-for="tag in modelValue"
        :key="tag"
        class="inline-flex items-center gap-1 rounded-md bg-n-alpha-2 px-2 py-0.5 text-xs text-n-text-display"
      >
        {{ tag }}
        <button
          type="button"
          class="text-n-slate-9 hover:text-n-text-display"
          @click.stop="remove(tag)"
        >
          <span class="i-lucide-x size-3" />
        </button>
      </span>
      <span v-if="modelValue.length === 0" class="text-sm text-n-slate-9 px-1">
        {{ placeholder }}
      </span>
    </div>

    <div
      v-if="open"
      class="absolute z-50 mt-1 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft shadow-lg"
    >
      <div class="p-2">
        <input
          v-model="search"
          type="text"
          :placeholder="t('NOTIFICATION_TEMPLATES.FORM.TAGS.SEARCH')"
          class="h-8 w-full rounded-md border border-n-border-glass-soft bg-n-alpha-1 px-2.5 text-xs text-n-text-display placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
          @click.stop
        />
      </div>
      <ul class="max-h-40 overflow-y-auto px-1 pb-1">
        <li
          v-for="label in filteredLabels"
          :key="label.id"
          class="flex items-center gap-2 rounded-md px-2 py-1.5 text-sm cursor-pointer hover:bg-n-alpha-2"
          @mousedown.prevent="toggle(label.title)"
        >
          <span
            class="size-3 rounded-full flex-shrink-0"
            :style="{ backgroundColor: label.color || '#1f93ff' }"
          />
          <span class="flex-1 text-n-text-display truncate">
            {{ label.title }}
          </span>
          <span
            v-if="isSelected(label.title)"
            class="i-lucide-check size-4 text-n-brand"
          />
        </li>
        <li
          v-if="filteredLabels.length === 0"
          class="px-2 py-2 text-xs text-n-slate-9 text-center"
        >
          {{ t('NOTIFICATION_TEMPLATES.FORM.TAGS.NO_LABELS') }}
        </li>
      </ul>
    </div>
  </div>
</template>
