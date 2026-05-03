<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';

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
const store = useStore();

const MAX_BUTTONS = 3;

const showForm = ref(false);
const newButtonLabel = ref('');
const newButtonType = ref('url');
const newButtonUrl = ref('');
const newButtonTemplateId = ref('');
const showQuickCreate = ref(false);
const isQuickCreating = ref(false);
const quickTemplateName = ref('');
const quickTemplateMessage = ref('');

const canQuickCreate = computed(
  () => quickTemplateName.value.trim() && quickTemplateMessage.value.trim()
);

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

const resetQuickCreateForm = () => {
  quickTemplateName.value = '';
  quickTemplateMessage.value = '';
};

const closeQuickCreate = () => {
  showQuickCreate.value = false;
  resetQuickCreateForm();
};

const createQuickTemplate = async () => {
  if (!canQuickCreate.value || isQuickCreating.value) return;
  isQuickCreating.value = true;
  try {
    const template = await store.dispatch('notificationTemplates/create', {
      name: quickTemplateName.value.trim(),
      messages: [
        {
          text: quickTemplateMessage.value.trim(),
          attachments: [],
          buttons: [],
        },
      ],
      enabled: true,
    });
    newButtonTemplateId.value = template?.id ?? '';
    useAlert(t('NOTIFICATION_TEMPLATES.QUICK_CREATE.SUCCESS'));
    closeQuickCreate();
  } catch {
    useAlert(t('NOTIFICATION_TEMPLATES.QUICK_CREATE.ERROR'));
  } finally {
    isQuickCreating.value = false;
  }
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
    <label class="text-sm font-medium text-n-text-display">
      {{ t('NOTIFICATION_TEMPLATES.BUTTONS.LABEL') }}
    </label>

    <!-- Existing buttons list -->
    <div v-if="modelValue.length" class="flex flex-col gap-1">
      <div
        v-for="btn in modelValue"
        :key="btn.id"
        class="flex items-center gap-2 rounded-lg border border-n-border-glass-soft bg-n-alpha-1 px-3 py-2"
      >
        <span
          class="i-lucide-mouse-pointer-click size-4 text-n-text-body/60 flex-shrink-0"
        />
        <div class="flex-1 min-w-0">
          <span class="text-sm font-medium text-n-text-display">{{
            btn.label
          }}</span>
          <span
            class="ml-2 text-xs text-n-text-body/60 inline-flex items-center gap-1"
          >
            <span class="i-lucide-arrow-right size-3" />
            <span v-if="btn.type === 'url'">{{ btn.url }}</span>
            <span v-else>{{ getTemplateName(btn.templateId) }}</span>
          </span>
        </div>
        <button
          class="text-n-text-body/60 hover:text-n-ruby-11 transition-colors flex-shrink-0"
          @click="removeButton(btn.id)"
        >
          <span class="i-lucide-x size-4" />
        </button>
      </div>
    </div>

    <p
      v-if="modelValue.length >= MAX_BUTTONS"
      class="text-xs text-n-text-body/60"
    >
      {{ t('NOTIFICATION_TEMPLATES.BUTTONS.MAX_REACHED') }}
    </p>

    <!-- Add button trigger -->
    <button
      v-if="modelValue.length < MAX_BUTTONS && !showForm"
      type="button"
      class="inline-flex items-center gap-1.5 self-start rounded-lg border border-dashed border-n-border-glass-soft px-3 py-1.5 text-xs text-n-text-body/60 hover:border-n-brand hover:text-n-text-display transition-colors"
      @click="showForm = true"
    >
      <span class="i-lucide-plus size-3.5" />
      {{ t('NOTIFICATION_TEMPLATES.BUTTONS.ADD') }}
    </button>

    <!-- New button form -->
    <div
      v-if="showForm"
      class="flex flex-col gap-2 rounded-lg border border-n-border-glass-soft bg-n-alpha-1 p-3"
    >
      <input
        v-model="newButtonLabel"
        type="text"
        :placeholder="t('NOTIFICATION_TEMPLATES.BUTTONS.BUTTON_LABEL')"
        class="h-8 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
      />
      <select
        v-model="newButtonType"
        class="h-8 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
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
        class="h-8 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
      />

      <select
        v-if="newButtonType === 'template'"
        v-model="newButtonTemplateId"
        class="h-8 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
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

      <button
        v-if="newButtonType === 'template'"
        type="button"
        class="self-start text-xs text-n-brand hover:text-n-brand/80 transition-colors"
        @click="showQuickCreate = true"
      >
        {{ t('NOTIFICATION_TEMPLATES.BUTTONS.CREATE_TEMPLATE') }}
      </button>

      <div class="flex gap-2">
        <button
          type="button"
          class="rounded-lg bg-n-brand px-3 py-1.5 text-xs text-white hover:bg-n-brand/90 transition-colors"
          @click="addButton"
        >
          {{ t('NOTIFICATION_TEMPLATES.BUTTONS.ADD') }}
        </button>
        <button
          type="button"
          class="rounded-lg border border-n-border-glass-soft px-3 py-1.5 text-xs text-n-text-body/60 hover:bg-n-alpha-1 transition-colors"
          @click="showForm = false"
        >
          {{ t('NOTIFICATION_TEMPLATES.COMMON.CANCEL') }}
        </button>
      </div>
    </div>
  </div>

  <Modal v-model:show="showQuickCreate" :on-close="closeQuickCreate">
    <div class="flex flex-col gap-4 p-6">
      <div class="flex flex-col gap-1">
        <p class="text-base font-semibold text-n-text-display">
          {{ t('NOTIFICATION_TEMPLATES.QUICK_CREATE.TITLE') }}
        </p>
        <p class="text-sm text-n-text-body/60">
          {{ t('NOTIFICATION_TEMPLATES.QUICK_CREATE.DESCRIPTION') }}
        </p>
      </div>

      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-text-display">
          {{ t('NOTIFICATION_TEMPLATES.QUICK_CREATE.NAME_LABEL') }}
        </label>
        <input
          v-model="quickTemplateName"
          type="text"
          :placeholder="
            t('NOTIFICATION_TEMPLATES.QUICK_CREATE.NAME_PLACEHOLDER')
          "
          class="h-10 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
        />
      </div>

      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-text-display">
          {{ t('NOTIFICATION_TEMPLATES.QUICK_CREATE.MESSAGE_LABEL') }}
        </label>
        <textarea
          v-model="quickTemplateMessage"
          :placeholder="
            t('NOTIFICATION_TEMPLATES.QUICK_CREATE.MESSAGE_PLACEHOLDER')
          "
          class="min-h-[6rem] w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 py-2 text-sm text-n-text-display placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
        />
      </div>

      <div class="flex items-center justify-end gap-2">
        <Button
          variant="faded"
          color="slate"
          :label="t('NOTIFICATION_TEMPLATES.QUICK_CREATE.CANCEL')"
          @click="closeQuickCreate"
        />
        <Button
          :label="t('NOTIFICATION_TEMPLATES.QUICK_CREATE.SUBMIT')"
          :is-loading="isQuickCreating"
          :disabled="!canQuickCreate"
          @click="createQuickTemplate"
        />
      </div>
    </div>
  </Modal>
</template>
