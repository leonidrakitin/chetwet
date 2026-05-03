<script setup>
import { ref, computed, watch, nextTick, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import NotificationTemplatePreview from './components/NotificationTemplatePreview.vue';
import TemplateMessageEditor from './components/TemplateMessageEditor.vue';
import AttachmentEditor from './components/AttachmentEditor.vue';
import ButtonEditor from './components/ButtonEditor.vue';
import TagMultiSelect from './components/TagMultiSelect.vue';
import SegmentMultiSelect from './components/SegmentMultiSelect.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const templateId = computed(() => route.params.templateId);
const isEditing = computed(() => !!templateId.value);

const template = computed(() =>
  isEditing.value
    ? store.getters['notificationTemplates/getTemplates'].find(
        tmpl => String(tmpl.id) === String(templateId.value)
      )
    : null
);

const allTemplates = computed(
  () => store.getters['notificationTemplates/getTemplates']
);
const notificationTemplateMeta = computed(
  () => store.getters['notificationTemplates/getMeta']
);
const availableInboxes = computed(() => store.getters['inboxes/getInboxes']);
const accountLabels = computed(() => store.getters['labels/getLabels']);
const contactSegments = computed(
  () => store.getters['customViews/getContactCustomViews']
);

const yclientsEnabled = computed(
  () => notificationTemplateMeta.value?.yclientsEnabled
);
const yclientsIntegrations = computed(
  () => notificationTemplateMeta.value?.yclientsIntegrations || []
);

const messageEditorRefs = ref([]);
const activeEditorIndex = ref(0);
const showAttachments = ref([]);
const activeVariable = ref(null);
const nameError = ref('');
const showMobilePreview = ref(false);

const collapsedSections = ref({
  trigger: false,
  audience: true,
  limits: true,
  yclients: true,
});

const toggleSection = section => {
  collapsedSections.value[section] = !collapsedSections.value[section];
};

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
    intervalValue: 30,
    intervalUnit: 'days',
    since: 'last_message',
    serviceName: '',
    staffName: '',
  },
  audience: {
    tags: [],
    excludeTags: [],
    segmentIds: [],
    segmentMatchMode: 'any',
    requireMailingConsent: false,
  },
  limits: {
    minIntervalValue: 24,
    minIntervalUnit: 'hours',
    quietHoursFrom: '22:00',
    quietHoursTo: '09:00',
    bypassGlobalLimits: false,
  },
  messages: [defaultBlock()],
  enabled: true,
});

const form = ref(defaultForm());

const typeOptions = computed(() => [
  { value: 'event', label: t('NOTIFICATION_TEMPLATES.TYPES.EVENT') },
  { value: 'time', label: t('NOTIFICATION_TEMPLATES.TYPES.TIME') },
  { value: 'interval', label: t('NOTIFICATION_TEMPLATES.TYPES.INTERVAL') },
]);

const intervalUnitOptions = computed(() => [
  {
    value: 'minutes',
    label: t('NOTIFICATION_TEMPLATES.FORM.INTERVAL_UNIT.MINUTES'),
  },
  {
    value: 'hours',
    label: t('NOTIFICATION_TEMPLATES.FORM.INTERVAL_UNIT.HOURS'),
  },
  { value: 'days', label: t('NOTIFICATION_TEMPLATES.FORM.INTERVAL_UNIT.DAYS') },
  {
    value: 'weeks',
    label: t('NOTIFICATION_TEMPLATES.FORM.INTERVAL_UNIT.WEEKS'),
  },
  {
    value: 'months',
    label: t('NOTIFICATION_TEMPLATES.FORM.INTERVAL_UNIT.MONTHS'),
  },
]);

const segmentMatchOptions = computed(() => [
  { value: 'any', label: t('NOTIFICATION_TEMPLATES.FORM.SEGMENT_MATCH.ANY') },
  { value: 'all', label: t('NOTIFICATION_TEMPLATES.FORM.SEGMENT_MATCH.ALL') },
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

const normalizeMessages = tmpl => {
  if (tmpl.messages?.length) {
    return tmpl.messages.map(message => ({
      text: normalizeVariableFormat(message.text ?? ''),
      attachments: [...(message.attachments ?? [])],
      buttons: [...(message.buttons ?? [])],
    }));
  }
  return [defaultBlock()];
};

const normalizeForm = tmpl => ({
  id: tmpl.id,
  name: tmpl.name ?? '',
  description: tmpl.description ?? '',
  type: tmpl.type ?? tmpl.template_type ?? 'event',
  triggerEvent: tmpl.triggerEvent ?? tmpl.event_type ?? 'conversation_created',
  inboxId: tmpl.inbox_id ?? tmpl.inbox?.id ?? '',
  yclientsIntegrationId:
    tmpl.yclients_integration_id ?? tmpl.yclients_integration?.id ?? '',
  schedule: {
    sendAt: tmpl.schedule?.send_at ?? '',
    timezone: tmpl.schedule?.timezone ?? 'UTC',
    repeat: tmpl.schedule?.repeat ?? 'none',
    repeatUntil: tmpl.schedule?.repeat_until ?? '',
  },
  conditions: {
    offsetHours: tmpl.conditions?.offset_hours ?? 0,
    intervalValue:
      tmpl.conditions?.interval_value ?? tmpl.conditions?.interval_days ?? 30,
    intervalUnit:
      tmpl.conditions?.interval_unit ??
      (tmpl.conditions?.interval_days != null ? 'days' : 'days'),
    since: tmpl.conditions?.since ?? 'last_message',
    serviceName: tmpl.conditions?.service_name ?? '',
    staffName: tmpl.conditions?.staff_name ?? '',
  },
  audience: {
    tags: [...(tmpl.audience?.tags ?? [])],
    excludeTags: [...(tmpl.audience?.exclude_tags ?? [])],
    segmentIds: [
      ...(tmpl.audience?.segment_ids ??
        (tmpl.audience?.segment_id ? [tmpl.audience.segment_id] : [])),
    ].map(Number),
    segmentMatchMode: tmpl.audience?.segment_match_mode ?? 'any',
    requireMailingConsent: tmpl.audience?.require_mailing_consent ?? false,
  },
  limits: {
    minIntervalValue:
      tmpl.limits?.min_interval_value ?? tmpl.limits?.min_interval_hours ?? 24,
    minIntervalUnit:
      tmpl.limits?.min_interval_unit ??
      (tmpl.limits?.min_interval_hours != null ? 'hours' : 'hours'),
    quietHoursFrom: tmpl.limits?.quiet_hours_from ?? '22:00',
    quietHoursTo: tmpl.limits?.quiet_hours_to ?? '09:00',
    bypassGlobalLimits: tmpl.limits?.bypass_global_limits ?? false,
  },
  messages: normalizeMessages(tmpl),
  enabled: tmpl.enabled ?? true,
});

watch(
  template,
  tmpl => {
    form.value = tmpl ? normalizeForm(tmpl) : defaultForm();
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
    const selected = yclientsIntegrations.value.find(
      i => i.id === Number(integrationId)
    );
    if (!selected?.inbox_id) return;
    form.value.inboxId = form.value.inboxId || selected.inbox_id;
  }
);

const goBack = () => {
  router.push({
    name: 'notification_templates_index',
    params: { accountId: route.params.accountId },
  });
};

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

const handleSave = async () => {
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

  const payload = {
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
      interval_value: Number(form.value.conditions.intervalValue || 0),
      interval_unit: form.value.conditions.intervalUnit,
      since: form.value.conditions.since,
      service_name: form.value.conditions.serviceName,
      staff_name: form.value.conditions.staffName,
    },
    audience: {
      tags: [...form.value.audience.tags],
      exclude_tags: [...form.value.audience.excludeTags],
      segment_ids: [...form.value.audience.segmentIds].map(Number),
      segment_match_mode: form.value.audience.segmentMatchMode,
      require_mailing_consent: form.value.audience.requireMailingConsent,
    },
    limits: {
      min_interval_value: Number(form.value.limits.minIntervalValue || 0),
      min_interval_unit: form.value.limits.minIntervalUnit,
      quiet_hours_from: form.value.limits.quietHoursFrom,
      quiet_hours_to: form.value.limits.quietHoursTo,
      bypass_global_limits: form.value.limits.bypassGlobalLimits,
    },
    messages,
    enabled: form.value.enabled,
    ...(template.value ? { order: template.value.order ?? 0 } : {}),
  };

  try {
    if (payload.id) {
      await store.dispatch('notificationTemplates/update', payload);
    } else {
      await store.dispatch('notificationTemplates/create', payload);
    }
    useAlert(t('NOTIFICATION_TEMPLATES.SAVE.SUCCESS'));
    goBack();
  } catch {
    useAlert(t('NOTIFICATION_TEMPLATES.SAVE.ERROR'));
  }
};

onMounted(() => {
  store.dispatch('notificationTemplates/get');
  if (!availableInboxes.value.length) {
    store.dispatch('inboxes/get');
  }
  if (!accountLabels.value.length) {
    store.dispatch('labels/get');
  }
  if (!contactSegments.value.length) {
    store.dispatch('customViews/get', { filter_type: 'contact' });
  }
});
</script>

<template>
  <div
    class="flex flex-col h-full w-full min-w-0 m-2.5 bg-n-glass-strong backdrop-blur-glass-card backdrop-saturate-glass border border-n-border-glass rounded-card-lg shadow-glass-deep overflow-hidden"
  >
    <!-- Header -->
    <div
      class="flex items-center justify-between gap-3 px-4 py-3 md:px-6 md:py-4 border-b border-n-border-hairline flex-shrink-0"
    >
      <div class="flex items-center gap-2 min-w-0">
        <Button
          icon="i-lucide-chevron-left"
          variant="link"
          color="slate"
          size="sm"
          :label="t('NOTIFICATION_TEMPLATES.HEADER')"
          @click="goBack"
        />
      </div>

      <div class="flex items-center gap-2 flex-shrink-0">
        <Button
          variant="faded"
          color="slate"
          :label="t('NOTIFICATION_TEMPLATES.FORM.CANCEL')"
          @click="goBack"
        />
        <Button
          :label="
            isEditing
              ? t('NOTIFICATION_TEMPLATES.EDIT.BUTTON_TEXT')
              : t('NOTIFICATION_TEMPLATES.ADD.TITLE')
          "
          @click="handleSave"
        />
      </div>
    </div>

    <!-- Scrollable content -->
    <div class="flex-1 min-h-0 overflow-y-auto">
      <div
        class="flex flex-col md:flex-row gap-4 md:gap-6 p-4 md:p-6 max-w-6xl mx-auto"
      >
        <!-- Mobile preview toggle -->
        <button
          type="button"
          class="md:hidden inline-flex items-center gap-1.5 self-start rounded-md border border-n-border-glass-soft px-2.5 py-1.5 text-xs text-n-text-body/60 hover:border-n-border-glass hover:text-n-text-display transition-colors flex-shrink-0"
          @click="showMobilePreview = !showMobilePreview"
        >
          <span
            class="size-3.5"
            :class="showMobilePreview ? 'i-lucide-eye-off' : 'i-lucide-eye'"
          />
          {{
            showMobilePreview
              ? t('NOTIFICATION_TEMPLATES.PREVIEW.HIDE')
              : t('NOTIFICATION_TEMPLATES.PREVIEW.TOGGLE')
          }}
        </button>

        <!-- Mobile preview -->
        <div v-if="showMobilePreview" class="md:hidden flex-shrink-0">
          <NotificationTemplatePreview
            :messages="form.messages"
            :active-variable="activeVariable"
          />
        </div>

        <div class="flex flex-col gap-4 flex-1 min-w-0 md:min-w-[22rem]">
          <div
            class="flex flex-col gap-4 rounded-xl border border-n-border-glass-soft bg-n-alpha-1 p-4"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="flex flex-col gap-1">
                <p class="text-sm font-semibold text-n-text-display">
                  {{ t('NOTIFICATION_TEMPLATES.SECTIONS.BASICS') }}
                </p>
                <p class="text-xs text-n-slate-9">
                  {{ t('NOTIFICATION_TEMPLATES.SECTIONS.BASICS_HINT') }}
                </p>
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="flex flex-col gap-1">
                <label class="text-sm font-medium text-n-text-display">
                  {{ t('NOTIFICATION_TEMPLATES.FORM.NAME.LABEL') }}
                  <span class="text-n-ruby-9">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.REQUIRED_INDICATOR') }}
                  </span>
                </label>
                <input
                  v-model="form.name"
                  type="text"
                  :placeholder="
                    t('NOTIFICATION_TEMPLATES.FORM.NAME.PLACEHOLDER')
                  "
                  class="h-10 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
                  @input="nameError = ''"
                />
                <span v-if="nameError" class="text-xs text-n-ruby-11">
                  {{ nameError }}
                </span>
              </div>

              <div class="flex flex-col gap-1">
                <label class="text-sm font-medium text-n-text-display">
                  {{ t('NOTIFICATION_TEMPLATES.FORM.DESCRIPTION.LABEL') }}
                </label>
                <input
                  v-model="form.description"
                  type="text"
                  :placeholder="
                    t('NOTIFICATION_TEMPLATES.FORM.DESCRIPTION.PLACEHOLDER')
                  "
                  class="h-10 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
                />
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="flex flex-col gap-1">
                <label class="text-sm font-medium text-n-text-display">
                  {{ t('NOTIFICATION_TEMPLATES.FORM.TYPE.LABEL') }}
                </label>
                <select
                  v-model="form.type"
                  class="h-10 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft pl-3 pr-8 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
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
                <label class="text-sm font-medium text-n-text-display">
                  {{
                    t('NOTIFICATION_TEMPLATES.FORM.YCLIENTS_INTEGRATION.LABEL')
                  }}
                </label>
                <select
                  v-model="form.yclientsIntegrationId"
                  class="h-10 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft pl-3 pr-8 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
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
                      t(
                        'NOTIFICATION_TEMPLATES.FORM.YCLIENTS_INTEGRATION.OPTION',
                        { salonId: integration.salon_id }
                      )
                    }}
                  </option>
                </select>
              </div>
            </div>
          </div>

          <!-- Trigger Settings (collapsible) -->
          <div
            class="rounded-xl border border-n-border-glass-soft bg-n-alpha-1 overflow-hidden"
          >
            <button
              type="button"
              class="flex items-center justify-between w-full px-4 py-3 text-left hover:bg-n-alpha-2 transition-colors"
              @click="toggleSection('trigger')"
            >
              <span class="text-sm font-medium text-n-text-display">
                {{ t('NOTIFICATION_TEMPLATES.SECTIONS.TRIGGER') }}
              </span>
              <span
                class="i-lucide-chevron-down size-4 text-n-slate-9 transition-transform"
                :class="{ 'rotate-180': !collapsedSections.trigger }"
              />
            </button>
            <div v-show="!collapsedSections.trigger" class="px-4 pb-4">
              <div
                v-if="form.type === 'event'"
                class="grid grid-cols-1 md:grid-cols-2 gap-3"
              >
                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.TRIGGER_EVENT.LABEL') }}
                  </label>
                  <select
                    v-model="form.triggerEvent"
                    class="h-9 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft pl-3 pr-8 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
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
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.OFFSET_HOURS.LABEL') }}
                  </label>
                  <input
                    v-model.number="form.conditions.offsetHours"
                    type="number"
                    class="h-9 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
                  />
                </div>
              </div>

              <div
                v-if="form.type === 'time'"
                class="grid grid-cols-1 md:grid-cols-2 gap-3"
              >
                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.SEND_AT.LABEL') }}
                  </label>
                  <input
                    v-model="form.schedule.sendAt"
                    type="datetime-local"
                    class="h-9 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
                  />
                </div>

                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.TIMEZONE.LABEL') }}
                  </label>
                  <input
                    v-model="form.schedule.timezone"
                    type="text"
                    class="h-9 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
                  />
                </div>

                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.REPEAT.LABEL') }}
                  </label>
                  <select
                    v-model="form.schedule.repeat"
                    class="h-9 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft pl-3 pr-8 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
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
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.REPEAT_UNTIL.LABEL') }}
                  </label>
                  <input
                    v-model="form.schedule.repeatUntil"
                    type="date"
                    class="h-9 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
                  />
                </div>
              </div>

              <div
                v-if="form.type === 'interval'"
                class="grid grid-cols-1 md:grid-cols-2 gap-3"
              >
                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.INTERVAL.LABEL') }}
                  </label>
                  <div class="flex gap-2">
                    <input
                      v-model.number="form.conditions.intervalValue"
                      type="number"
                      min="1"
                      class="h-9 w-24 rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
                    />
                    <select
                      v-model="form.conditions.intervalUnit"
                      class="h-9 flex-1 rounded-lg border border-n-border-glass-soft bg-n-glass-soft pl-3 pr-8 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
                    >
                      <option
                        v-for="option in intervalUnitOptions"
                        :key="option.value"
                        :value="option.value"
                      >
                        {{ option.label }}
                      </option>
                    </select>
                  </div>
                </div>

                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.SINCE.LABEL') }}
                  </label>
                  <select
                    v-model="form.conditions.since"
                    class="h-9 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft pl-3 pr-8 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
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

                <div class="flex flex-col gap-1 md:col-span-2">
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.MIN_INTERVAL.LABEL') }}
                  </label>
                  <div class="flex gap-2">
                    <input
                      v-model.number="form.limits.minIntervalValue"
                      type="number"
                      min="0"
                      class="h-9 w-24 rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
                    />
                    <select
                      v-model="form.limits.minIntervalUnit"
                      class="h-9 flex-1 rounded-lg border border-n-border-glass-soft bg-n-glass-soft pl-3 pr-8 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
                    >
                      <option
                        v-for="option in intervalUnitOptions"
                        :key="option.value"
                        :value="option.value"
                      >
                        {{ option.label }}
                      </option>
                    </select>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- YClients Filters (collapsible) -->
          <div
            v-if="yclientsEnabled"
            class="rounded-xl border border-n-border-glass-soft bg-n-alpha-1 overflow-hidden"
          >
            <button
              type="button"
              class="flex items-center justify-between w-full px-4 py-3 text-left hover:bg-n-alpha-2 transition-colors"
              @click="toggleSection('yclients')"
            >
              <span class="text-sm font-medium text-n-text-display">
                {{ t('NOTIFICATION_TEMPLATES.SECTIONS.YCLIENTS') }}
              </span>
              <span
                class="i-lucide-chevron-down size-4 text-n-slate-9 transition-transform"
                :class="{ 'rotate-180': !collapsedSections.yclients }"
              />
            </button>
            <div v-show="!collapsedSections.yclients" class="px-4 pb-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.SERVICE_NAME.LABEL') }}
                  </label>
                  <input
                    v-model="form.conditions.serviceName"
                    type="text"
                    :placeholder="
                      t('NOTIFICATION_TEMPLATES.FORM.SERVICE_NAME.PLACEHOLDER')
                    "
                    class="h-9 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
                  />
                </div>

                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.STAFF_NAME.LABEL') }}
                  </label>
                  <input
                    v-model="form.conditions.staffName"
                    type="text"
                    :placeholder="
                      t('NOTIFICATION_TEMPLATES.FORM.STAFF_NAME.PLACEHOLDER')
                    "
                    class="h-9 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
                  />
                </div>
              </div>
            </div>
          </div>

          <!-- Audience Settings (collapsible) -->
          <div
            class="rounded-xl border border-n-border-glass-soft bg-n-alpha-1 overflow-hidden"
          >
            <button
              type="button"
              class="flex items-center justify-between w-full px-4 py-3 text-left hover:bg-n-alpha-2 transition-colors"
              @click="toggleSection('audience')"
            >
              <span class="text-sm font-medium text-n-text-display">
                {{ t('NOTIFICATION_TEMPLATES.SECTIONS.AUDIENCE') }}
              </span>
              <span
                class="i-lucide-chevron-down size-4 text-n-slate-9 transition-transform"
                :class="{ 'rotate-180': !collapsedSections.audience }"
              />
            </button>
            <div v-show="!collapsedSections.audience" class="px-4 pb-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div class="flex flex-col gap-1 md:col-span-2">
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.INBOX_FILTER.LABEL') }}
                  </label>
                  <select
                    v-model="form.inboxId"
                    class="h-9 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft pl-3 pr-8 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
                  >
                    <option value="">
                      {{
                        t(
                          'NOTIFICATION_TEMPLATES.FORM.INBOX_FILTER.PLACEHOLDER'
                        )
                      }}
                    </option>
                    <option
                      v-for="inbox in availableInboxes"
                      :key="inbox.id"
                      :value="inbox.id"
                    >
                      {{ inbox.name }}
                    </option>
                  </select>
                  <span class="text-xs text-n-slate-9">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.INBOX_FILTER.HINT') }}
                  </span>
                </div>

                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.TAGS.LABEL') }}
                  </label>
                  <TagMultiSelect
                    v-model="form.audience.tags"
                    :labels="accountLabels"
                    :placeholder="
                      t('NOTIFICATION_TEMPLATES.FORM.TAGS.PLACEHOLDER')
                    "
                  />
                </div>

                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-text-body">
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

                <div class="flex flex-col gap-1 md:col-span-2">
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.SEGMENTS.LABEL') }}
                  </label>
                  <SegmentMultiSelect
                    v-model="form.audience.segmentIds"
                    :segments="contactSegments"
                    :placeholder="
                      t('NOTIFICATION_TEMPLATES.FORM.SEGMENTS.PLACEHOLDER')
                    "
                  />
                </div>

                <div
                  v-if="form.audience.segmentIds.length > 1"
                  class="flex flex-col gap-1 md:col-span-2"
                >
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.SEGMENT_MATCH.LABEL') }}
                  </label>
                  <div class="flex gap-2">
                    <button
                      v-for="option in segmentMatchOptions"
                      :key="option.value"
                      type="button"
                      class="h-9 px-3 rounded-lg border text-sm transition-colors"
                      :class="
                        form.audience.segmentMatchMode === option.value
                          ? 'border-n-brand bg-n-brand/10 text-n-brand'
                          : 'border-n-border-glass-soft bg-n-glass-soft text-n-text-body hover:border-n-border-glass'
                      "
                      @click="form.audience.segmentMatchMode = option.value"
                    >
                      {{ option.label }}
                    </button>
                  </div>
                </div>
              </div>

              <div
                v-if="yclientsEnabled"
                class="flex items-center gap-3 mt-3 pt-3 border-t border-n-border-glass-soft"
              >
                <Switch v-model="form.audience.requireMailingConsent" />
                <label class="text-xs font-medium text-n-text-body">
                  {{
                    t(
                      'NOTIFICATION_TEMPLATES.FORM.REQUIRE_MAILING_CONSENT.LABEL'
                    )
                  }}
                </label>
              </div>
            </div>
          </div>

          <!-- Limits Settings (collapsible) -->
          <div
            class="rounded-xl border border-n-border-glass-soft bg-n-alpha-1 overflow-hidden"
          >
            <button
              type="button"
              class="flex items-center justify-between w-full px-4 py-3 text-left hover:bg-n-alpha-2 transition-colors"
              @click="toggleSection('limits')"
            >
              <span class="text-sm font-medium text-n-text-display">
                {{ t('NOTIFICATION_TEMPLATES.SECTIONS.LIMITS') }}
              </span>
              <span
                class="i-lucide-chevron-down size-4 text-n-slate-9 transition-transform"
                :class="{ 'rotate-180': !collapsedSections.limits }"
              />
            </button>
            <div v-show="!collapsedSections.limits" class="px-4 pb-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-text-body">
                    {{
                      t('NOTIFICATION_TEMPLATES.FORM.QUIET_HOURS_FROM.LABEL')
                    }}
                  </label>
                  <input
                    v-model="form.limits.quietHoursFrom"
                    type="time"
                    class="h-9 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
                  />
                </div>

                <div class="flex flex-col gap-1">
                  <label class="text-xs font-medium text-n-text-body">
                    {{ t('NOTIFICATION_TEMPLATES.FORM.QUIET_HOURS_TO.LABEL') }}
                  </label>
                  <input
                    v-model="form.limits.quietHoursTo"
                    type="time"
                    class="h-9 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display focus:border-n-brand focus:outline-none"
                  />
                </div>
              </div>

              <div
                class="flex flex-col gap-2 mt-3 pt-3 border-t border-n-border-glass-soft"
              >
                <div class="flex items-center gap-3">
                  <Switch v-model="form.limits.bypassGlobalLimits" />
                  <label class="text-xs font-medium text-n-text-body">
                    {{
                      t(
                        'NOTIFICATION_TEMPLATES.FORM.BYPASS_GLOBAL_LIMITS.LABEL'
                      )
                    }}
                  </label>
                </div>

                <div
                  v-if="form.limits.bypassGlobalLimits"
                  class="flex items-start gap-2.5 rounded-lg bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800/50 px-3 py-2.5"
                >
                  <span
                    class="i-lucide-triangle-alert size-3.5 text-amber-600 dark:text-amber-400 mt-0.5 flex-shrink-0"
                  />
                  <p
                    class="text-xs text-amber-800 dark:text-amber-300 leading-relaxed"
                  >
                    {{
                      t(
                        'NOTIFICATION_TEMPLATES.FORM.BYPASS_GLOBAL_LIMITS.WARNING'
                      )
                    }}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <!-- Message Editor (always visible) -->
          <div
            class="flex flex-col gap-4 rounded-xl border border-n-border-glass-soft bg-n-alpha-1 p-4"
          >
            <p class="text-sm font-semibold text-n-text-display">
              {{ t('NOTIFICATION_TEMPLATES.FORM.MESSAGE_TEXT.LABEL') }}
            </p>

            <div
              v-for="(block, idx) in form.messages"
              :key="idx"
              class="flex flex-col gap-2 rounded-xl border border-n-border-glass-soft bg-n-glass-soft p-3"
            >
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-0.5">
                  <button
                    v-if="idx > 0"
                    type="button"
                    class="rounded p-1 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-text-display"
                    @click="moveMessageUp(idx)"
                  >
                    <span class="i-lucide-arrow-up size-3.5" />
                  </button>
                  <button
                    v-if="idx < form.messages.length - 1"
                    type="button"
                    class="rounded p-1 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-text-display"
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
              class="inline-flex items-center gap-1.5 self-start rounded-md border border-dashed border-n-border-glass-soft px-2.5 py-1.5 text-xs text-n-text-body/60 hover:border-n-border-glass hover:text-n-text-display"
              @click="addMessage"
            >
              <span class="i-lucide-plus size-3.5" />
              {{ t('NOTIFICATION_TEMPLATES.FORM.MESSAGE_TEXT.ADD_MESSAGE') }}
            </button>

            <div
              class="flex items-center gap-3 pt-2 border-t border-n-border-glass-soft"
            >
              <Switch v-model="form.enabled" />
              <label class="text-sm font-medium text-n-text-display">
                {{ t('NOTIFICATION_TEMPLATES.FORM.ENABLED.LABEL') }}
              </label>
            </div>
          </div>
        </div>

        <!-- Desktop preview sidebar -->
        <div class="hidden md:block w-80 flex-shrink-0 self-start sticky top-0">
          <NotificationTemplatePreview
            :messages="form.messages"
            :active-variable="activeVariable"
          />
        </div>
      </div>
    </div>
  </div>
</template>
