<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  segments: { type: Array, default: () => [] },
  placeholder: { type: String, default: '' },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const open = ref(false);
const search = ref('');
const containerRef = ref(null);

const filteredSegments = computed(() => {
  const q = search.value.trim().toLowerCase();
  if (!q) return props.segments;
  return props.segments.filter(segment =>
    (segment.name || '').toLowerCase().includes(q)
  );
});

const segmentById = computed(() => {
  const map = {};
  props.segments.forEach(s => {
    map[s.id] = s;
  });
  return map;
});

const isSelected = id => props.modelValue.map(Number).includes(Number(id));

const toggle = id => {
  const numericId = Number(id);
  const current = props.modelValue.map(Number);
  const idx = current.indexOf(numericId);
  if (idx >= 0) {
    current.splice(idx, 1);
  } else {
    current.push(numericId);
  }
  emit('update:modelValue', current);
};

const remove = id => {
  emit(
    'update:modelValue',
    props.modelValue.map(Number).filter(v => v !== Number(id))
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
      class="flex flex-wrap items-center gap-1 min-h-[2.5rem] w-full rounded-lg border border-n-weak bg-n-solid-1 px-2 py-1 cursor-pointer"
      @click="open = !open"
    >
      <span
        v-for="id in modelValue"
        :key="id"
        class="inline-flex items-center gap-1 rounded-md bg-n-alpha-2 px-2 py-0.5 text-xs text-n-slate-12"
      >
        {{ segmentById[id]?.name || `#${id}` }}
        <button
          type="button"
          class="text-n-slate-9 hover:text-n-slate-12"
          @click.stop="remove(id)"
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
      class="absolute z-50 mt-1 w-full rounded-lg border border-n-weak bg-n-solid-1 shadow-lg"
    >
      <div class="p-2">
        <input
          v-model="search"
          type="text"
          :placeholder="t('NOTIFICATION_TEMPLATES.FORM.SEGMENTS.SEARCH')"
          class="h-8 w-full rounded-md border border-n-weak bg-n-alpha-1 px-2.5 text-xs text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
          @click.stop
        />
      </div>
      <ul class="max-h-40 overflow-y-auto px-1 pb-1">
        <li
          v-for="segment in filteredSegments"
          :key="segment.id"
          class="flex items-center gap-2 rounded-md px-2 py-1.5 text-sm cursor-pointer hover:bg-n-alpha-2"
          @mousedown.prevent="toggle(segment.id)"
        >
          <span class="i-lucide-filter size-3 text-n-slate-9 flex-shrink-0" />
          <span class="flex-1 text-n-slate-12 truncate">
            {{ segment.name }}
          </span>
          <span
            v-if="isSelected(segment.id)"
            class="i-lucide-check size-4 text-n-brand"
          />
        </li>
        <li
          v-if="filteredSegments.length === 0"
          class="px-2 py-2 text-xs text-n-slate-9 text-center"
        >
          {{ t('NOTIFICATION_TEMPLATES.FORM.SEGMENTS.NO_SEGMENTS') }}
        </li>
      </ul>
    </div>
  </div>
</template>
