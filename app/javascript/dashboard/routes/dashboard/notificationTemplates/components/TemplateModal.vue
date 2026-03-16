<script setup>
import { ref, computed, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import NotificationTemplatePreview from './NotificationTemplatePreview.vue';
import TemplateMessageEditor from './TemplateMessageEditor.vue';
import AttachmentEditor from './AttachmentEditor.vue';
import ButtonEditor from './ButtonEditor.vue';
import TagMultiSelect from './TagMultiSelect.vue';

const props = defineProps({
  template: { type: Object, default: null },
  allTemplates: { type: Array, default: () => [] },
  availableInboxes: { type: Array, default: () => [] },
  accountLabels: { type: Array, default: () => [] },
  meta: {
    type: Object,
    default: () => ({
      yclientsEnabled: false,
      yclientsIntegrations: [],
    }),
  },
});

const emit = defineEmits(['save', 'close']);
const { t } = useI18n();

const dialogRef = ref(null);
const messageEditorRefs = ref([]);
const activeEditorIndex = ref(0);
const showAttachments = ref([]);
const activeVariable = ref(null);
const nameError = ref('');

const defaultBlock = () => ({ text: '', attachments: [], buttons: [] });

const defaultForm = () => ({
  id: null,
  name: '',
  description: '',
  type: 'event',
  triggerEvent: 'conversation_created',
  inboxId: '',
  yclientsIntegrationId: '',
  schedule: {
    sendAt: '',
    timezone: 'UTC',
    repeat: 'none',
    repeatUntil: '',
  },
  conditions: {
    offsetHours: 0,
    intervalDays: 30,
    since: 'last_message',
    serviceName: '',
    staffName: '',
  },
  audience: {
    tags: [],
    excludeTags: [],
  },
  limits: {
    minIntervalHours: 24,
    quietHoursFrom: '22:00',
    quietHoursTo: '09:00',
    maxPerDay: 3,
    stopIfReplied: true,
    skipIfHasActiveDialog: true,
  },
  messages: [defaultBlock()],
  enabled: true,
});

const form = ref(defaultForm());
const isEditing = computed(() => !!props.template);
const yclientsEnabled = computed(() => props.meta?.yclientsEnabled);
const yclientsIntegrations = computed(
  () => props.meta?.yclientsIntegrations || []
);

const typeOptions = computed(() => [
  { value: 'event', label: t('NOTIFICATION_TEMPLATES.TYPES.EVENT') },
  { value: 'time', label: t('NOTIFICATION_TEMPLATES.TYPES.TIME') },
  { value: 'interval', label: t('NOTIFICATION_TEMPLATES.TYPES.INTERVAL') },
]);

const triggerEventOptions = computed(() => {
  const options = [
    {
      value: 'conversation_created',
      label: t('NOTIFICATION_TEMPLATES.EVENTS.CONVERSATION_CREATED'),
    },
    {
      value: 'conversation_resolved',
      label: t('NOTIFICATION_TEMPLATES.EVENTS.CONVERSATION_RESOLVED'),
    },
    {
      value: 'message_received',
      label: t('NOTIFICATION_TEMPLATES.EVENTS.MESSAGE_RECEIVED'),
    },
  ];

  if (yclientsEnabled.value) {
    options.push(
      {
        value: 'booking_created',
        label: t('NOTIFICATION_TEMPLATES.EVENTS.BOOKING_CREATED'),
      },
      {
        value: 'booking_cancelled',
        label: t('NOTIFICATION_TEMPLATES.EVENTS.BOOKING_CANCELLED'),
      },
      {
        value: 'confirmed',
        label: t('NOTIFICATION_TEMPLATES.EVENTS.CONFIRMED'),
      },
      { value: 'paid', label: t('NOTIFICATION_TEMPLATES.EVENTS.PAID') },
      { value: 'arrived', label: t('NOTIFICATION_TEMPLATES.EVENTS.ARRIVED') }
    );
  }

  return options;
});

const repeatOptions = computed(() => [
  { value: 'none', label: t('NOTIFICATION_TEMPLATES.REPEAT.NONE') },
  { value: 'daily', label: t('NOTIFICATION_TEMPLATES.REPEAT.DAILY') },
  { value: 'weekly', label: t('NOTIFICATION_TEMPLATES.REPEAT.WEEKLY') },
  { value: 'monthly', label: t('NOTIFICATION_TEMPLATES.REPEAT.MONTHLY') },
]);

const intervalSinceOptions = computed(() => {
  const options = [
    {
      value: 'last_message',
      label: t('NOTIFICATION_TEMPLATES.SINCE.LAST_MESSAGE'),
    },
    {
      value: 'registration_date',
      label: t('NOTIFICATION_TEMPLATES.SINCE.REGISTRATION_DATE'),
    },
  ];

  if (yclientsEnabled.value) {
    options.unshift({
      value: 'last_visit',
      label: t('NOTIFICATION_TEMPLATES.SINCE.LAST_VISIT'),
    });
  }

  return options;
});

const normalizeVariableFormat = text =>
  (text ?? '').replace(/\{(\w+)\}/g, '@$1');

const normalizeMessages = template => {
  if (template.messages?.length) {
    return template.messages.map(message => ({
      text: normalizeVariableFormat(message.text ?? ''),
      attachments: [...(message.attachments ?? [])],
      buttons: [...(message.buttons ?? [])],
    }));
  }

  return [defaultBlock()];
};

const normalizeForm = template => ({
  id: template.id,
  name: template.name ?? '',
  description: template.description ?? '',
  type: template.type ?? template.template_type ?? 'event',
  triggerEvent:
    template.triggerEvent ?? template.event_type ?? 'conversation_created',
  inboxId: template.inbox_id ?? template.inbox?.id ?? '',
  yclientsIntegrationId:
    template.yclients_integration_id ?? template.yclients_integration?.id ?? '',
  schedule: {
    sendAt: template.schedule?.send_at ?? '',
    timezone: template.schedule?.timezone ?? 'UTC',
    repeat: template.schedule?.repeat ?? 'none',
    repeatUntil: template.schedule?.repeat_until ?? '',
  },
  conditions: {
    offsetHours: template.conditions?.offset_hours ?? 0,
    intervalDays: template.conditions?.interval_days ?? 30,
    since: template.conditions?.since ?? 'last_message',
    serviceName: template.conditions?.service_name ?? '',
    staffName: template.conditions?.staff_name ?? '',
  },
  audience: {
    tags: [...(template.audience?.tags ?? [])],
    excludeTags: [...(template.audience?.exclude_tags ?? [])],
  },
  limits: {
    minIntervalHours: template.limits?.min_interval_hours ?? 24,
    quietHoursFrom: template.limits?.quiet_hours_from ?? '22:00',
    quietHoursTo: template.limits?.quiet_hours_to ?? '09:00',
    maxPerDay: template.limits?.max_per_day ?? 3,
    stopIfReplied: template.limits?.stop_if_replied ?? true,
    skipIfHasActiveDialog: template.limits?.skip_if_has_active_dialog ?? true,
  },
  messages: normalizeMessages(template),
  enabled: template.enabled ?? true,
});

watch(
  () => props.template,
  template => {
    form.value = template ? normalizeForm(template) : defaultForm();
    nameError.value = '';
    activeEditorIndex.value = 0;
    messageEditorRefs.value = [];
    showAttachments.value = form.value.messages.map(() => false);
  },
  { immediate: true }
);

watch(
  () => form.value.yclientsIntegrationId,
  integrationId => {
    if (!integrationId) return;

    const selectedIntegration = yclientsIntegrations.value.find(
      integration => integration.id === Number(integrationId)
    );
    if (!selectedIntegration?.inbox_id) return;

    form.value.inboxId = form.value.inboxId || selectedIntegration.inbox_id;
  }
);

const open = () => dialogRef.value?.open();
const close = () => dialogRef.value?.close();
defineExpose({ open, close });

const setEditorRef = (el, idx) => {
  messageEditorRefs.value[idx] = el;
};

const addMessage = () => {
  form.value.messages.push(defaultBlock());
  showAttachments.value.push(false);
  const newIdx = form.value.messages.length - 1;
  nextTick(() => {
    activeEditorIndex.value = newIdx;
    messageEditorRefs.value[newIdx]?.focus();
  });
};

const removeMessage = idx => {
  form.value.messages.splice(idx, 1);
  messageEditorRefs.value.splice(idx, 1);
  showAttachments.value.splice(idx, 1);
  if (activeEditorIndex.value >= form.value.messages.length) {
    activeEditorIndex.value = form.value.messages.length - 1;
  }
};

const moveMessageUp = idx => {
  if (idx <= 0) return;
  const arr = form.value.messages;
  [arr[idx - 1], arr[idx]] = [arr[idx], arr[idx - 1]];
  const toggles = showAttachments.value;
  [toggles[idx - 1], toggles[idx]] = [toggles[idx], toggles[idx - 1]];
  activeEditorIndex.value = idx - 1;
  nextTick(() => messageEditorRefs.value[idx - 1]?.focus());
};

const moveMessageDown = idx => {
  if (idx >= form.value.messages.length - 1) return;
  const arr = form.value.messages;
  [arr[idx], arr[idx + 1]] = [arr[idx + 1], arr[idx]];
  const toggles = showAttachments.value;
  [toggles[idx], toggles[idx + 1]] = [toggles[idx + 1], toggles[idx]];
  activeEditorIndex.value = idx + 1;
  nextTick(() => messageEditorRefs.value[idx + 1]?.focus());
};

const toggleAttachments = idx => {
  showAttachments.value[idx] = !showAttachments.value[idx];
};

const handleConfirm = () => {
  if (!form.value.name.trim()) {
    nameError.value = t('NOTIFICATION_TEMPLATES.FORM.NAME.REQUIRED');
    return;
  }

  const messages = form.value.messages.filter(
    message =>
      message.text.trim() ||
      message.attachments.length ||
      message.buttons.length
  );

  emit('save', {
    id: form.value.id,
    name: form.value.name,
    description: form.value.description,
    type: form.value.type,
    template_type: form.value.type,
    triggerEvent: form.value.triggerEvent,
    event_type: form.value.triggerEvent,
    inbox_id: form.value.inboxId || null,
    yclients_integration_id: form.value.yclientsIntegrationId || null,
    schedule: {
      send_at: form.value.schedule.sendAt || null,
      timezone: form.value.schedule.timezone,
      repeat: form.value.schedule.repeat,
      repeat_until: form.value.schedule.repeatUntil || null,
    },
    conditions: {
      offset_hours: Number(form.value.conditions.offsetHours || 0),
      interval_days: Number(form.value.conditions.intervalDays || 0),
      since: form.value.conditions.since,
      service_name: form.value.conditions.serviceName,
      staff_name: form.value.conditions.staffName,
    },
    audience: {
      tags: [...form.value.audience.tags],
      exclude_tags: [...form.value.audience.excludeTags],
    },
    limits: {
      min_interval_hours: Number(form.value.limits.minIntervalHours || 0),
      quiet_hours_from: form.value.limits.quietHoursFrom,
      quiet_hours_to: form.value.limits.quietHoursTo,
      max_per_day: Number(form.value.limits.maxPerDay || 0),
      stop_if_replied: form.value.limits.stopIfReplied,
      skip_if_has_active_dialog: form.value.limits.skipIfHasActiveDialog,
    },
    messages,
    enabled: form.value.enabled,
    ...(props.template ? { order: props.template.order ?? 0 } : {}),
  });
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
    width="6xl"
    max-height="90vh"
    @confirm="handleConfirm"
    @close="handleClose"
  >
    <div class="flex flex-row gap-6 min-h-0">
      <div class="flex flex-col gap-4 flex-1 min-w-[22rem]">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('NOTIFICATION_TEMPLATES.FORM.NAME.LABEL') }}
              <span class="text-n-ruby-9">
                {{ t('NOTIFICATION_TEMPLATES.FORM.REQUIRED_INDICATOR') }}
              </span>
            </label>
            <input
              v-model="form.name"
              type="text"
              :placeholder="t('NOTIFICATION_TEMPLATES.FORM.NAME.PLACEHOLDER')"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
              @input="nameError = ''"
            />
            <span v-if="nameError" class="text-xs text-n-ruby-11">
              {{ nameError }}
            </span>
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('NOTIFICATION_TEMPLATES.FORM.INBOX.LABEL') }}
            </label>
            <select
              v-model="form.inboxId"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-alpha-1 pl-3 pr-8 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            >
              <option value="">
                {{ t('NOTIFICATION_TEMPLATES.FORM.INBOX.PLACEHOLDER') }}
              </option>
              <option
                v-for="inbox in availableInboxes"
                :key="inbox.id"
                :value="inbox.id"
              >
                {{ inbox.name }}
              </option>
            </select>
          </div>
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
            class="h-10 w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
          />
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('NOTIFICATION_TEMPLATES.FORM.TYPE.LABEL') }}
            </label>
            <select
              v-model="form.type"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-alpha-1 pl-3 pr-8 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            >
              <option
                v-for="option in typeOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </div>

          <div v-if="yclientsEnabled" class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('NOTIFICATION_TEMPLATES.FORM.YCLIENTS_INTEGRATION.LABEL') }}
            </label>
            <select
              v-model="form.yclientsIntegrationId"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-alpha-1 pl-3 pr-8 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            >
              <option value="">
                {{
                  t(
                    'NOTIFICATION_TEMPLATES.FORM.YCLIENTS_INTEGRATION.PLACEHOLDER'
                  )
                }}
              </option>
              <option
                v-for="integration in yclientsIntegrations"
                :key="integration.id"
                :value="integration.id"
              >
                {{
                  t('NOTIFICATION_TEMPLATES.FORM.YCLIENTS_INTEGRATION.OPTION', {
                    salonId: integration.salon_id,
                  })
                }}
              </option>
            </select>
          </div>
        </div>

        <div
          v-if="form.type === 'event'"
          class="grid grid-cols-1 md:grid-cols-2 gap-4 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
        >
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('NOTIFICATION_TEMPLATES.FORM.TRIGGER_EVENT.LABEL') }}
            </label>
            <select
              v-model="form.triggerEvent"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 pl-3 pr-8 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            >
              <option
                v-for="option in triggerEventOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('NOTIFICATION_TEMPLATES.FORM.OFFSET_HOURS.LABEL') }}
            </label>
            <input
              v-model.number="form.conditions.offsetHours"
              type="number"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            />
          </div>
        </div>

        <div
          v-if="form.type === 'time'"
          class="grid grid-cols-1 md:grid-cols-2 gap-4 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
        >
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('NOTIFICATION_TEMPLATES.FORM.SEND_AT.LABEL') }}
            </label>
            <input
              v-model="form.schedule.sendAt"
              type="datetime-local"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            />
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('NOTIFICATION_TEMPLATES.FORM.TIMEZONE.LABEL') }}
            </label>
            <input
              v-model="form.schedule.timezone"
              type="text"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            />
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('NOTIFICATION_TEMPLATES.FORM.REPEAT.LABEL') }}
            </label>
            <select
              v-model="form.schedule.repeat"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 pl-3 pr-8 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            >
              <option
                v-for="option in repeatOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('NOTIFICATION_TEMPLATES.FORM.REPEAT_UNTIL.LABEL') }}
            </label>
            <input
              v-model="form.schedule.repeatUntil"
              type="date"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            />
          </div>
        </div>

        <div
          v-if="form.type === 'interval'"
          class="grid grid-cols-1 md:grid-cols-3 gap-4 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
        >
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('NOTIFICATION_TEMPLATES.FORM.INTERVAL_DAYS.LABEL') }}
            </label>
            <input
              v-model.number="form.conditions.intervalDays"
              type="number"
              min="1"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            />
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('NOTIFICATION_TEMPLATES.FORM.SINCE.LABEL') }}
            </label>
            <select
              v-model="form.conditions.since"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 pl-3 pr-8 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            >
              <option
                v-for="option in intervalSinceOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('NOTIFICATION_TEMPLATES.FORM.MIN_INTERVAL_HOURS.LABEL') }}
            </label>
            <input
              v-model.number="form.limits.minIntervalHours"
              type="number"
              min="0"
              class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            />
          </div>
        </div>

        <div
          v-if="yclientsEnabled"
          class="grid grid-cols-1 md:grid-cols-2 gap-4 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
        >
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('NOTIFICATION_TEMPLATES.FORM.SERVICE_NAME.LABEL') }}
            </label>
            <input
              v-model="form.conditions.serviceName"
              type="text"
              :placeholder="
                t('NOTIFICATION_TEMPLATES.FORM.SERVICE_NAME.PLACEHOLDER')
              "
              class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            />
          </div>

          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('NOTIFICATION_TEMPLATES.FORM.STAFF_NAME.LABEL') }}
            </label>
            <input
              v-model="form.conditions.staffName"
              type="text"
              :placeholder="
                t('NOTIFICATION_TEMPLATES.FORM.STAFF_NAME.PLACEHOLDER')
              "
              class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            />
          </div>
        </div>

        <div
          class="flex flex-col gap-4 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
        >
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="flex flex-col gap-1">
              <label class="text-sm font-medium text-n-slate-12">
                {{ t('NOTIFICATION_TEMPLATES.FORM.TAGS.LABEL') }}
              </label>
              <TagMultiSelect
                v-model="form.audience.tags"
                :labels="accountLabels"
                :placeholder="t('NOTIFICATION_TEMPLATES.FORM.TAGS.PLACEHOLDER')"
              />
            </div>

            <div class="flex flex-col gap-1">
              <label class="text-sm font-medium text-n-slate-12">
                {{ t('NOTIFICATION_TEMPLATES.FORM.EXCLUDE_TAGS.LABEL') }}
              </label>
              <TagMultiSelect
                v-model="form.audience.excludeTags"
                :labels="accountLabels"
                :placeholder="
                  t('NOTIFICATION_TEMPLATES.FORM.EXCLUDE_TAGS.PLACEHOLDER')
                "
              />
            </div>

            <div class="flex flex-col gap-1">
              <label class="text-sm font-medium text-n-slate-12">
                {{ t('NOTIFICATION_TEMPLATES.FORM.QUIET_HOURS_FROM.LABEL') }}
              </label>
              <input
                v-model="form.limits.quietHoursFrom"
                type="time"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
              />
            </div>

            <div class="flex flex-col gap-1">
              <label class="text-sm font-medium text-n-slate-12">
                {{ t('NOTIFICATION_TEMPLATES.FORM.QUIET_HOURS_TO.LABEL') }}
              </label>
              <input
                v-model="form.limits.quietHoursTo"
                type="time"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
              />
            </div>

            <div class="flex flex-col gap-1">
              <label class="text-sm font-medium text-n-slate-12">
                {{ t('NOTIFICATION_TEMPLATES.FORM.MAX_PER_DAY.LABEL') }}
              </label>
              <input
                v-model.number="form.limits.maxPerDay"
                type="number"
                min="1"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
              />
            </div>
          </div>

          <div class="flex flex-col gap-3 border-t border-n-weak pt-4">
            <div class="flex items-center gap-3">
              <Switch v-model="form.limits.stopIfReplied" />
              <label class="text-sm font-medium text-n-slate-12">
                {{ t('NOTIFICATION_TEMPLATES.FORM.STOP_IF_REPLIED.LABEL') }}
              </label>
            </div>
            <div class="flex items-center gap-3">
              <Switch v-model="form.limits.skipIfHasActiveDialog" />
              <label class="text-sm font-medium text-n-slate-12">
                {{
                  t(
                    'NOTIFICATION_TEMPLATES.FORM.SKIP_IF_HAS_ACTIVE_DIALOG.LABEL'
                  )
                }}
              </label>
            </div>
          </div>
        </div>

        <div class="flex flex-col gap-3">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('NOTIFICATION_TEMPLATES.FORM.MESSAGE_TEXT.LABEL') }}
          </label>

          <div
            v-for="(block, idx) in form.messages"
            :key="idx"
            class="flex flex-col gap-2 rounded-xl border border-n-weak bg-n-alpha-1 p-3"
          >
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-0.5">
                <button
                  v-if="idx > 0"
                  type="button"
                  class="rounded p-1 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12"
                  @click="moveMessageUp(idx)"
                >
                  <span class="i-lucide-arrow-up size-3.5" />
                </button>
                <button
                  v-if="idx < form.messages.length - 1"
                  type="button"
                  class="rounded p-1 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12"
                  @click="moveMessageDown(idx)"
                >
                  <span class="i-lucide-arrow-down size-3.5" />
                </button>
              </div>
              <button
                v-if="form.messages.length > 1"
                type="button"
                class="rounded p-1 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-ruby-11"
                @click="removeMessage(idx)"
              >
                <span class="i-lucide-trash-2 size-3.5" />
              </button>
            </div>

            <div class="min-h-0 min-w-0" @focusin="activeEditorIndex = idx">
              <TemplateMessageEditor
                :ref="el => setEditorRef(el, idx)"
                :model-value="form.messages[idx].text"
                :placeholder="
                  t('NOTIFICATION_TEMPLATES.FORM.MESSAGE_TEXT.PLACEHOLDER')
                "
                @update:model-value="form.messages[idx].text = $event"
                @toggle-attachments="toggleAttachments(idx)"
                @variable-select="key => (activeVariable = key)"
              />
            </div>

            <AttachmentEditor
              v-show="showAttachments[idx]"
              v-model="form.messages[idx].attachments"
            />

            <ButtonEditor
              v-model="form.messages[idx].buttons"
              :templates="allTemplates"
              :current-id="form.id"
            />
          </div>

          <button
            type="button"
            class="inline-flex items-center gap-1.5 self-start rounded-md border border-dashed border-n-weak px-2.5 py-1.5 text-xs text-n-slate-10 hover:border-n-strong hover:text-n-slate-12"
            @click="addMessage"
          >
            <span class="i-lucide-plus size-3.5" />
            {{ t('NOTIFICATION_TEMPLATES.FORM.MESSAGE_TEXT.ADD_MESSAGE') }}
          </button>
        </div>

        <div class="flex items-center gap-3">
          <Switch v-model="form.enabled" />
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('NOTIFICATION_TEMPLATES.FORM.ENABLED.LABEL') }}
          </label>
        </div>
      </div>

      <div class="w-80 flex-shrink-0">
        <NotificationTemplatePreview
          :messages="form.messages"
          :active-variable="activeVariable"
        />
      </div>
    </div>
  </Dialog>
</template>
