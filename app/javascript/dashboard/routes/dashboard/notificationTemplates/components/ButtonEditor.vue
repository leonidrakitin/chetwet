<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => [],
  },
  templates: {
    type: Array,
    default: () => [],
  },
  currentId: {
    type: [Number, String],
    default: null,
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const MAX_BUTTONS = 3;

const showForm = ref(false);
const newButtonLabel = ref('');
const newButtonType = ref('url');
const newButtonUrl = ref('');
const newButtonTemplateId = ref('');

let nextIdCounter = 1;
const genId = () => {
  nextIdCounter += 1;
  return `btn-${Date.now()}-${nextIdCounter}`;
};

const availableTemplates = () =>
  props.templates.filter(tmpl => tmpl.id !== props.currentId);

const removeButton = id => {
  emit(
    'update:modelValue',
    props.modelValue.filter(b => b.id !== id)
  );
};

const getTemplateName = templateId => {
  const tmpl = props.templates.find(tmpl2 => tmpl2.id === Number(templateId));
  return tmpl?.name ?? String(templateId);
};

const addButton = () => {
  if (!newButtonLabel.value.trim()) return;
  if (newButtonType.value === 'url' && !newButtonUrl.value.trim()) return;
  if (newButtonType.value === 'template' && !newButtonTemplateId.value) return;
  if (props.modelValue.length >= MAX_BUTTONS) return;

  const btn = {
    id: genId(),
    label: newButtonLabel.value.trim(),
    type: newButtonType.value,
  };
  if (newButtonType.value === 'url') {
    btn.url = newButtonUrl.value.trim();
  } else {
    btn.templateId = Number(newButtonTemplateId.value);
  }
  emit('update:modelValue', [...props.modelValue, btn]);
  newButtonLabel.value = '';
  newButtonType.value = 'url';
  newButtonUrl.value = '';
  newButtonTemplateId.value = '';
  showForm.value = false;
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <label class="text-sm font-medium text-n-slate-12">
      {{ t('NOTIFICATION_TEMPLATES.BUTTONS.LABEL') }}
    </label>

    <!-- Existing buttons list -->
    <div v-if="modelValue.length" class="flex flex-col gap-1">
      <div
        v-for="btn in modelValue"
        :key="btn.id"
        class="flex items-center gap-2 rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2"
      >
        <span
          class="i-lucide-mouse-pointer-click size-4 text-n-slate-10 flex-shrink-0"
        />
        <div class="flex-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">{{
            btn.label
          }}</span>
          <span
            class="ml-2 text-xs text-n-slate-10 inline-flex items-center gap-1"
          >
            <span class="i-lucide-arrow-right size-3" />
            <span v-if="btn.type === 'url'">{{ btn.url }}</span>
            <span v-else>{{ getTemplateName(btn.templateId) }}</span>
          </span>
        </div>
        <button
          class="text-n-slate-10 hover:text-n-ruby-11 transition-colors flex-shrink-0"
          @click="removeButton(btn.id)"
        >
          <span class="i-lucide-x size-4" />
        </button>
      </div>
    </div>

    <p v-if="modelValue.length >= MAX_BUTTONS" class="text-xs text-n-slate-10">
      {{ t('NOTIFICATION_TEMPLATES.BUTTONS.MAX_REACHED') }}
    </p>

    <!-- Add button trigger -->
    <button
      v-if="modelValue.length < MAX_BUTTONS && !showForm"
      class="inline-flex items-center gap-1.5 self-start rounded-lg border border-dashed border-n-weak px-3 py-1.5 text-xs text-n-slate-10 hover:border-n-brand hover:text-n-slate-12 transition-colors"
      @click="showForm = true"
    >
      <span class="i-lucide-plus size-3.5" />
      {{ t('NOTIFICATION_TEMPLATES.BUTTONS.ADD') }}
    </button>

    <!-- New button form -->
    <div
      v-if="showForm"
      class="flex flex-col gap-2 rounded-lg border border-n-weak bg-n-alpha-1 p-3"
    >
      <input
        v-model="newButtonLabel"
        type="text"
        :placeholder="t('NOTIFICATION_TEMPLATES.BUTTONS.BUTTON_LABEL')"
        class="h-8 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
      />
      <select
        v-model="newButtonType"
        class="h-8 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
      >
        <option value="url">
          {{ t('NOTIFICATION_TEMPLATES.BUTTONS.TYPE_URL') }}
        </option>
        <option value="template">
          {{ t('NOTIFICATION_TEMPLATES.BUTTONS.TYPE_TEMPLATE') }}
        </option>
      </select>

      <input
        v-if="newButtonType === 'url'"
        v-model="newButtonUrl"
        type="url"
        :placeholder="t('NOTIFICATION_TEMPLATES.BUTTONS.URL')"
        class="h-8 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
      />

      <select
        v-if="newButtonType === 'template'"
        v-model="newButtonTemplateId"
        class="h-8 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
      >
        <option value="">
          {{ t('NOTIFICATION_TEMPLATES.BUTTONS.TEMPLATE') }}
        </option>
        <option
          v-for="tmpl in availableTemplates()"
          :key="tmpl.id"
          :value="tmpl.id"
        >
          {{ tmpl.name }}
        </option>
      </select>

      <div class="flex gap-2">
        <button
          class="rounded-lg bg-n-brand px-3 py-1.5 text-xs text-white hover:bg-n-brand/90 transition-colors"
          @click="addButton"
        >
          {{ t('NOTIFICATION_TEMPLATES.BUTTONS.ADD') }}
        </button>
        <button
          class="rounded-lg border border-n-weak px-3 py-1.5 text-xs text-n-slate-10 hover:bg-n-alpha-1 transition-colors"
          @click="showForm = false"
        >
          {{ t('NOTIFICATION_TEMPLATES.COMMON.CANCEL') }}
        </button>
      </div>
    </div>
  </div>
</template>
