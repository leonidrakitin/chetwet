<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import NotificationTemplatePreview from './NotificationTemplatePreview.vue';

const props = defineProps({
  template: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['save', 'close']);

const { t } = useI18n();

const dialogRef = ref(null);

const isEditing = computed(() => !!props.template);

const defaultForm = () => ({
  name: '',
  description: '',
  type: 'event',
  triggerEvent: 'CREATED',
  timeOffset: 24,
  timeUnit: 'HOURS',
  timeDirection: 'BEFORE',
  messageText: '',
  enabled: true,
});

const form = ref(defaultForm());
const nameError = ref('');

watch(
  () => props.template,
  template => {
    if (template) {
      form.value = { ...template };
    } else {
      form.value = defaultForm();
    }
    nameError.value = '';
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
  emit('save', { ...form.value });
  close();
};

const handleClose = () => {
  emit('close');
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
    width="3xl"
    overflow-y-auto
    @confirm="handleConfirm"
    @close="handleClose"
  >
    <div class="flex flex-row gap-6">
      <div class="flex flex-col gap-4 flex-1">
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

        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('NOTIFICATION_TEMPLATES.FORM.MESSAGE_TEXT.LABEL') }}
          </label>
          <textarea
            v-model="form.messageText"
            rows="4"
            :placeholder="
              t('NOTIFICATION_TEMPLATES.FORM.MESSAGE_TEXT.PLACEHOLDER')
            "
            class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none transition-colors resize-none"
          />
          <p class="text-xs text-n-slate-9">
            {{ t('NOTIFICATION_TEMPLATES.VARIABLES_HINT') }}
          </p>
        </div>

        <div class="flex items-center gap-3">
          <Switch v-model="form.enabled" />
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('NOTIFICATION_TEMPLATES.FORM.ENABLED.LABEL') }}
          </label>
        </div>
      </div>

      <div class="w-64 flex-shrink-0">
        <NotificationTemplatePreview :message-text="form.messageText" />
      </div>
    </div>
  </Dialog>
</template>
