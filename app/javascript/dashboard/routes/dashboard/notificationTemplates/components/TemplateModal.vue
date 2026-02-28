<script setup>
import { ref, computed, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import NotificationTemplatePreview from './NotificationTemplatePreview.vue';
import VariablePicker from './VariablePicker.vue';
import TemplateMessageEditor from './TemplateMessageEditor.vue';
import AttachmentEditor from './AttachmentEditor.vue';
import ButtonEditor from './ButtonEditor.vue';

const props = defineProps({
  template: {
    type: Object,
    default: null,
  },
  allTemplates: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['save', 'close']);

const { t } = useI18n();

const dialogRef = ref(null);
const messageEditorRefs = ref([]);
const activeEditorIndex = ref(0);
const highlightVariableKey = ref(null);

const isEditing = computed(() => !!props.template);

const defaultBlock = () => ({ text: '', attachments: [], buttons: [] });

const defaultForm = () => ({
  name: '',
  description: '',
  type: 'event',
  triggerEvent: 'CREATED',
  timeOffset: 24,
  timeUnit: 'HOURS',
  timeDirection: 'BEFORE',
  messages: [defaultBlock()],
  enabled: true,
});

const form = ref(defaultForm());
const nameError = ref('');

const normalizeVariableFormat = text =>
  (text ?? '').replace(/\{(\w+)\}/g, '@$1');

const migrateMessages = template => {
  if (template.messages?.length) {
    const first = template.messages[0];
    if (typeof first === 'string') {
      return template.messages.map((text, i) => ({
        text: normalizeVariableFormat(text),
        attachments: i === 0 ? [...(template.attachments ?? [])] : [],
        buttons: i === 0 ? [...(template.buttons ?? [])] : [],
      }));
    }
    return template.messages.map(m => ({
      text: normalizeVariableFormat(m.text ?? ''),
      attachments: [...(m.attachments ?? [])],
      buttons: [...(m.buttons ?? [])],
    }));
  }
  if (template.messageText) {
    return [
      {
        text: normalizeVariableFormat(template.messageText),
        attachments: [...(template.attachments ?? [])],
        buttons: [...(template.buttons ?? [])],
      },
    ];
  }
  return [defaultBlock()];
};

watch(
  () => props.template,
  template => {
    if (template) {
      const { attachments, buttons, messageText, ...rest } = template;
      form.value = {
        ...defaultForm(),
        ...rest,
        messages: migrateMessages(template),
      };
    } else {
      form.value = defaultForm();
    }
    nameError.value = '';
    activeEditorIndex.value = 0;
    messageEditorRefs.value = [];
  },
  { immediate: true }
);

const typeOptions = [
  { value: 'event', label: t('NOTIFICATION_TEMPLATES.TYPES.EVENT') },
  { value: 'time', label: t('NOTIFICATION_TEMPLATES.TYPES.TIME') },
  {
    value: 'lost_clients',
    label: t('NOTIFICATION_TEMPLATES.TYPES.LOST_CLIENTS'),
  },
  {
    value: 'client_consent',
    label: t('NOTIFICATION_TEMPLATES.TYPES.CLIENT_CONSENT'),
  },
];

const triggerEventOptions = [
  { value: 'CREATED', label: t('NOTIFICATION_TEMPLATES.EVENTS.CREATED') },
  { value: 'UPDATED', label: t('NOTIFICATION_TEMPLATES.EVENTS.UPDATED') },
  { value: 'DELETED', label: t('NOTIFICATION_TEMPLATES.EVENTS.DELETED') },
  { value: 'CONFIRMED', label: t('NOTIFICATION_TEMPLATES.EVENTS.CONFIRMED') },
  { value: 'CANCELLED', label: t('NOTIFICATION_TEMPLATES.EVENTS.CANCELLED') },
  { value: 'PAID', label: t('NOTIFICATION_TEMPLATES.EVENTS.PAID') },
  { value: 'ARRIVED', label: t('NOTIFICATION_TEMPLATES.EVENTS.ARRIVED') },
];

const timeUnitOptions = [
  { value: 'HOURS', label: t('NOTIFICATION_TEMPLATES.TIME_UNIT.HOURS') },
  { value: 'DAYS', label: t('NOTIFICATION_TEMPLATES.TIME_UNIT.DAYS') },
];

const timeDirectionOptions = [
  { value: 'BEFORE', label: t('NOTIFICATION_TEMPLATES.TIME_DIRECTION.BEFORE') },
  { value: 'AFTER', label: t('NOTIFICATION_TEMPLATES.TIME_DIRECTION.AFTER') },
];

const open = () => dialogRef.value?.open();
const close = () => dialogRef.value?.close();

defineExpose({ open, close });

const handleConfirm = () => {
  if (!form.value.name.trim()) {
    nameError.value = t('NOTIFICATION_TEMPLATES.FORM.NAME.REQUIRED');
    return;
  }
  const messages = form.value.messages.filter(
    m => m.text.trim() || m.attachments.length || m.buttons.length
  );
  emit('save', { ...form.value, messages });
  close();
};

const handleClose = () => {
  emit('close');
};

const setEditorRef = (el, idx) => {
  messageEditorRefs.value[idx] = el;
};

const insertVariable = text => {
  messageEditorRefs.value[activeEditorIndex.value]?.insertAtCursor(text);
};

const addMessage = () => {
  form.value.messages.push(defaultBlock());
  const newIdx = form.value.messages.length - 1;
  nextTick(() => {
    activeEditorIndex.value = newIdx;
    messageEditorRefs.value[newIdx]?.focus();
  });
};

const removeMessage = idx => {
  form.value.messages.splice(idx, 1);
  messageEditorRefs.value.splice(idx, 1);
  if (activeEditorIndex.value >= form.value.messages.length) {
    activeEditorIndex.value = form.value.messages.length - 1;
  }
};

const moveMessageUp = idx => {
  if (idx <= 0) return;
  const arr = form.value.messages;
  [arr[idx - 1], arr[idx]] = [arr[idx], arr[idx - 1]];
  activeEditorIndex.value = idx - 1;
  nextTick(() => messageEditorRefs.value[idx - 1]?.focus());
};

const moveMessageDown = idx => {
  if (idx >= form.value.messages.length - 1) return;
  const arr = form.value.messages;
  [arr[idx], arr[idx + 1]] = [arr[idx + 1], arr[idx]];
  activeEditorIndex.value = idx + 1;
  nextTick(() => messageEditorRefs.value[idx + 1]?.focus());
};
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="
      isEditing
        ? t('NOTIFICATION_TEMPLATES.EDIT.TITLE')
        : t('NOTIFICATION_TEMPLATES.ADD.TITLE')
    "
    :confirm-button-label="
      isEditing
        ? t('NOTIFICATION_TEMPLATES.EDIT.BUTTON_TEXT')
        : t('NOTIFICATION_TEMPLATES.ADD.TITLE')
    "
    width="4xl"
    @confirm="handleConfirm"
    @close="handleClose"
  >
    <div class="flex flex-row gap-6 max-h-[80vh] min-h-0">
      <div class="flex flex-col gap-4 flex-1 min-w-0 min-h-0 overflow-y-auto">
        <!-- Name -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('NOTIFICATION_TEMPLATES.FORM.NAME.LABEL') }}
            <span class="text-n-ruby-9">*</span>
          </label>
          <input
            v-model="form.name"
            type="text"
            :placeholder="t('NOTIFICATION_TEMPLATES.FORM.NAME.PLACEHOLDER')"
            class="h-10 w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none transition-colors"
            @input="nameError = ''"
          />
          <span v-if="nameError" class="text-xs text-n-ruby-11">{{
            nameError
          }}</span>
        </div>

        <!-- Description -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('NOTIFICATION_TEMPLATES.FORM.DESCRIPTION.LABEL') }}
          </label>
          <input
            v-model="form.description"
            type="text"
            :placeholder="
              t('NOTIFICATION_TEMPLATES.FORM.DESCRIPTION.PLACEHOLDER')
            "
            class="h-10 w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none transition-colors"
          />
        </div>

        <!-- Type -->
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('NOTIFICATION_TEMPLATES.FORM.TYPE.LABEL') }}
          </label>
          <select
            v-model="form.type"
            class="h-10 w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none transition-colors"
          >
            <option
              v-for="opt in typeOptions"
              :key="opt.value"
              :value="opt.value"
            >
              {{ opt.label }}
            </option>
          </select>
        </div>

        <!-- Trigger event (for event type) -->
        <div v-if="form.type === 'event'" class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('NOTIFICATION_TEMPLATES.FORM.TRIGGER_EVENT.LABEL') }}
          </label>
          <select
            v-model="form.triggerEvent"
            class="h-10 w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none transition-colors"
          >
            <option
              v-for="opt in triggerEventOptions"
              :key="opt.value"
              :value="opt.value"
            >
              {{ opt.label }}
            </option>
          </select>
        </div>

        <!-- Time offset (for time type) -->
        <div v-if="form.type === 'time'" class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('NOTIFICATION_TEMPLATES.FORM.TIME_OFFSET.LABEL') }}
          </label>
          <div class="flex items-center gap-2">
            <input
              v-model.number="form.timeOffset"
              type="number"
              min="1"
              class="h-10 w-24 rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none transition-colors"
            />
            <select
              v-model="form.timeUnit"
              class="h-10 flex-1 rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none transition-colors"
            >
              <option
                v-for="opt in timeUnitOptions"
                :key="opt.value"
                :value="opt.value"
              >
                {{ opt.label }}
              </option>
            </select>
            <select
              v-model="form.timeDirection"
              class="h-10 flex-1 rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none transition-colors"
            >
              <option
                v-for="opt in timeDirectionOptions"
                :key="opt.value"
                :value="opt.value"
              >
                {{ opt.label }}
              </option>
            </select>
          </div>
        </div>

        <!-- Messages -->
        <div class="flex flex-col gap-3">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('NOTIFICATION_TEMPLATES.FORM.MESSAGE_TEXT.LABEL') }}
          </label>

          <div
            v-for="(block, idx) in form.messages"
            :key="idx"
            class="flex flex-col gap-3 rounded-xl border border-n-weak bg-n-alpha-1 p-3"
          >
            <!-- Block header -->
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-0.5">
                <button
                  v-if="idx > 0"
                  v-tooltip.top="
                    t('NOTIFICATION_TEMPLATES.FORM.MESSAGE_TEXT.MOVE_UP_ARIA')
                  "
                  type="button"
                  class="rounded p-1 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
                  @click="moveMessageUp(idx)"
                >
                  <span class="i-lucide-arrow-up size-3.5" />
                </button>
                <button
                  v-if="idx < form.messages.length - 1"
                  v-tooltip.top="
                    t('NOTIFICATION_TEMPLATES.FORM.MESSAGE_TEXT.MOVE_DOWN_ARIA')
                  "
                  type="button"
                  class="rounded p-1 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
                  @click="moveMessageDown(idx)"
                >
                  <span class="i-lucide-arrow-down size-3.5" />
                </button>
              </div>
              <button
                v-if="form.messages.length > 1"
                v-tooltip.top="
                  t(
                    'NOTIFICATION_TEMPLATES.FORM.MESSAGE_TEXT.REMOVE_MESSAGE_ARIA'
                  )
                "
                type="button"
                class="rounded p-1 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-ruby-11 transition-colors"
                @click="removeMessage(idx)"
              >
                <span class="i-lucide-trash-2 size-3.5" />
              </button>
            </div>

            <!-- Text editor -->
            <div @focusin="activeEditorIndex = idx">
              <TemplateMessageEditor
                :ref="el => setEditorRef(el, idx)"
                :model-value="form.messages[idx].text"
                :placeholder="
                  t('NOTIFICATION_TEMPLATES.FORM.MESSAGE_TEXT.PLACEHOLDER')
                "
                @update:model-value="form.messages[idx].text = $event"
              />
            </div>

            <!-- Attachments for this block -->
            <AttachmentEditor v-model="form.messages[idx].attachments" />

            <!-- Buttons for this block -->
            <ButtonEditor
              v-model="form.messages[idx].buttons"
              :templates="allTemplates"
              :current-id="form.id"
            />
          </div>

          <!-- Add message -->
          <button
            type="button"
            class="inline-flex items-center gap-1.5 self-start rounded-md border border-dashed border-n-weak px-2.5 py-1.5 text-xs text-n-slate-10 hover:border-n-strong hover:text-n-slate-12 transition-colors"
            @click="addMessage"
          >
            <span class="i-lucide-plus size-3.5" />
            {{ t('NOTIFICATION_TEMPLATES.FORM.MESSAGE_TEXT.ADD_MESSAGE') }}
          </button>

          <!-- Variable picker -->
          <VariablePicker
            @insert="insertVariable"
            @drag-start="highlightVariableKey = $event"
            @drag-end="highlightVariableKey = null"
            @highlight-variable="highlightVariableKey = $event"
          />
        </div>

        <!-- Enabled toggle -->
        <div class="flex items-center gap-3">
          <Switch v-model="form.enabled" />
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('NOTIFICATION_TEMPLATES.FORM.ENABLED.LABEL') }}
          </label>
        </div>
      </div>

      <!-- Preview panel -->
      <div
        class="w-80 flex-shrink-0 self-start sticky top-4 overflow-y-auto min-h-0 max-h-[80vh]"
      >
        <NotificationTemplatePreview
          :messages="form.messages"
          :highlight-variable-key="highlightVariableKey"
        />
      </div>
    </div>
  </Dialog>
</template>
