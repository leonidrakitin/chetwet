<script setup>
import { ref, computed, watch, nextTick, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import NotificationTemplatePreview from '../notificationTemplates/components/NotificationTemplatePreview.vue';
import TemplateMessageEditor from '../notificationTemplates/components/TemplateMessageEditor.vue';
import AttachmentEditor from '../notificationTemplates/components/AttachmentEditor.vue';
import ButtonEditor from '../notificationTemplates/components/ButtonEditor.vue';
import TagMultiSelect from '../notificationTemplates/components/TagMultiSelect.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const campaignId = computed(() => route.params.campaignId);
const isEditing = computed(() => !!campaignId.value);

const campaign = computed(() =>
  isEditing.value
    ? store.getters['campaigns/getCampaigns'].find(
        c => String(c.id) === String(campaignId.value)
      )
    : null
);

const allTemplates = computed(
  () => store.getters['notificationTemplates/getTemplates']
);
const campaignsMeta = computed(() => store.getters['campaigns/getMeta']);
const availableInboxes = computed(() => store.getters['inboxes/getInboxes']);
const accountLabels = computed(() => store.getters['labels/getLabels']);
const contactSegments = computed(
  () => store.getters['customViews/getContactCustomViews']
);

const yclientsEnabled = computed(() => campaignsMeta.value?.yclientsEnabled);
const yclientsIntegrations = computed(
  () => campaignsMeta.value?.yclientsIntegrations || []
);

const messageEditorRefs = ref([]);
const activeEditorIndex = ref(0);
const showAttachments = ref([]);
const activeVariable = ref(null);
const nameError = ref('');
const showMobilePreview = ref(false);

const defaultBlock = () => ({ text: '', attachments: [], buttons: [] });

const defaultForm = () => ({
  id: null,
  name: '',
  description: '',
  inboxId: '',
  yclientsIntegrationId: '',
  scheduledAt: '',
  audience: {
    tags: [],
    excludeTags: [],
    segmentId: '',
  },
  messages: [defaultBlock()],
  enabled: true,
});

const form = ref(defaultForm());

const normalizeMessages = c => {
  if (c.messages?.length) {
    return c.messages.map(message => ({
      text: (message.text ?? '').replace(/\{(\w+)\}/g, '@$1'),
      attachments: [...(message.attachments ?? [])],
      buttons: [...(message.buttons ?? [])],
    }));
  }
  return [defaultBlock()];
};

const normalizeForm = c => ({
  id: c.id,
  name: c.name ?? '',
  description: c.description ?? '',
  inboxId: c.inbox_id ?? c.inbox?.id ?? '',
  yclientsIntegrationId:
    c.yclients_integration_id ?? c.yclients_integration?.id ?? '',
  scheduledAt: c.scheduled_at ?? '',
  audience: {
    tags: [...(c.audience?.tags ?? [])],
    excludeTags: [...(c.audience?.exclude_tags ?? [])],
    segmentId: c.audience?.segment_id ?? '',
  },
  messages: normalizeMessages(c),
  enabled: c.enabled ?? true,
});

watch(
  campaign,
  c => {
    form.value = c ? normalizeForm(c) : defaultForm();
    nameError.value = '';
    activeEditorIndex.value = 0;
    messageEditorRefs.value = [];
    showAttachments.value = form.value.messages.map(() => false);
  },
  { immediate: true }
);

const goBack = () => {
  router.push({
    name: 'campaigns_index',
    params: { accountId: route.params.accountId },
  });
};

const audiencePreview = ref(null);
const isPreviewingAudience = ref(false);
const isSending = ref(false);
const showSendConfirm = ref(false);

const previewAudience = async () => {
  if (!isEditing.value) return;
  isPreviewingAudience.value = true;
  try {
    audiencePreview.value = await store.dispatch(
      'campaigns/previewAudience',
      campaignId.value
    );
  } catch {
    useAlert(t('CAMPAIGNS.PREVIEW_ERROR'));
  } finally {
    isPreviewingAudience.value = false;
  }
};

const handleSendNow = async () => {
  showSendConfirm.value = false;
  isSending.value = true;
  try {
    await store.dispatch('campaigns/sendNow', campaignId.value);
    useAlert(t('CAMPAIGNS.SEND_SUCCESS'));
    goBack();
  } catch {
    useAlert(t('CAMPAIGNS.SEND_ERROR'));
  } finally {
    isSending.value = false;
  }
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
    inbox_id: form.value.inboxId || null,
    yclients_integration_id: form.value.yclientsIntegrationId || null,
    scheduled_at: form.value.scheduledAt || null,
    audience: {
      tags: [...form.value.audience.tags],
      exclude_tags: [...form.value.audience.excludeTags],
      segment_id: form.value.audience.segmentId || null,
    },
    messages,
    enabled: form.value.enabled,
  };

  try {
    if (payload.id) {
      await store.dispatch('campaigns/update', payload);
    } else {
      await store.dispatch('campaigns/create', payload);
    }
    useAlert(t('CAMPAIGNS.SAVE.SUCCESS'));
    goBack();
  } catch {
    useAlert(t('CAMPAIGNS.SAVE.ERROR'));
  }
};

onMounted(() => {
  store.dispatch('campaigns/get');
  store.dispatch('customViews/get', { filter_type: 'contact' });
  if (!allTemplates.value.length) {
    store.dispatch('notificationTemplates/get');
  }
  if (!availableInboxes.value.length) {
    store.dispatch('inboxes/get');
  }
  if (!accountLabels.value.length) {
    store.dispatch('labels/get');
  }
});
</script>

<template>
  <div class="flex flex-col h-full w-full min-w-0 bg-n-surface-1">
    <!-- Header -->
    <div
      class="flex items-center justify-between gap-3 px-4 py-3 md:px-6 md:py-4 border-b border-n-weak flex-shrink-0"
    >
      <div class="flex items-center gap-2 min-w-0">
        <Button
          icon="i-lucide-chevron-left"
          variant="link"
          color="slate"
          size="sm"
          :label="t('CAMPAIGNS.HEADER')"
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
              : t('CAMPAIGNS.NEW_CAMPAIGN')
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
          class="md:hidden inline-flex items-center gap-1.5 self-start rounded-md border border-n-weak px-2.5 py-1.5 text-xs text-n-slate-10 hover:border-n-strong hover:text-n-slate-12 transition-colors flex-shrink-0"
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
            class="flex flex-col gap-4 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="flex flex-col gap-1">
                <p class="text-sm font-semibold text-n-slate-12">
                  {{ t('CAMPAIGNS.SECTIONS.BASICS') }}
                </p>
                <p class="text-xs text-n-slate-9">
                  {{ t('CAMPAIGNS.SECTIONS.BASICS_HINT') }}
                </p>
              </div>
            </div>

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
                  :placeholder="
                    t('NOTIFICATION_TEMPLATES.FORM.NAME.PLACEHOLDER')
                  "
                  class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
                  @input="nameError = ''"
                />
                <span v-if="nameError" class="text-xs text-n-ruby-11">
                  {{ nameError }}
                </span>
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
                  class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
                />
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div v-if="yclientsEnabled" class="flex flex-col gap-1">
                <label class="text-sm font-medium text-n-slate-12">
                  {{
                    t('NOTIFICATION_TEMPLATES.FORM.YCLIENTS_INTEGRATION.LABEL')
                  }}
                </label>
                <select
                  v-model="form.yclientsIntegrationId"
                  class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 pl-3 pr-8 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
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

              <div class="flex flex-col gap-1">
                <label class="text-sm font-medium text-n-slate-12">
                  {{ t('CAMPAIGNS.SCHEDULED_AT') }}
                </label>
                <input
                  v-model="form.scheduledAt"
                  type="datetime-local"
                  class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
                />
                <span class="text-xs text-n-slate-9">
                  {{ t('CAMPAIGNS.SCHEDULED_AT_HINT') }}
                </span>
              </div>
            </div>
          </div>

          <!-- Audience -->
          <div
            class="flex flex-col gap-4 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="flex flex-col gap-1">
                <p class="text-sm font-semibold text-n-slate-12">
                  {{ t('CAMPAIGNS.SECTIONS.AUDIENCE') }}
                </p>
                <p class="text-xs text-n-slate-9">
                  {{ t('CAMPAIGNS.SECTIONS.AUDIENCE_HINT') }}
                </p>
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="flex flex-col gap-1">
                <label class="text-sm font-medium text-n-slate-12">
                  {{ t('CAMPAIGNS.SEGMENT_LABEL') }}
                </label>
                <select
                  v-model="form.audience.segmentId"
                  class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 pl-3 pr-8 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
                >
                  <option value="">
                    {{ t('CAMPAIGNS.SEGMENT_PLACEHOLDER') }}
                  </option>
                  <option
                    v-for="segment in contactSegments"
                    :key="segment.id"
                    :value="segment.id"
                  >
                    {{ segment.name }}
                  </option>
                </select>
              </div>

              <div class="flex flex-col gap-1">
                <label class="text-sm font-medium text-n-slate-12">
                  {{ t('NOTIFICATION_TEMPLATES.FORM.INBOX_FILTER.LABEL') }}
                </label>
                <select
                  v-model="form.inboxId"
                  class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 pl-3 pr-8 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
                >
                  <option value="">
                    {{
                      t('NOTIFICATION_TEMPLATES.FORM.INBOX_FILTER.PLACEHOLDER')
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
                <label class="text-sm font-medium text-n-slate-12">
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
            </div>
          </div>

          <!-- Send actions (only for existing campaigns) -->
          <div
            v-if="isEditing"
            class="flex flex-col gap-3 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
          >
            <div class="flex items-center gap-2">
              <Button
                variant="faded"
                color="slate"
                size="sm"
                icon="i-lucide-users"
                :label="t('CAMPAIGNS.PREVIEW_AUDIENCE')"
                :is-loading="isPreviewingAudience"
                @click="previewAudience"
              />
              <Button
                variant="faded"
                size="sm"
                icon="i-lucide-send"
                :label="t('CAMPAIGNS.SEND_NOW')"
                :is-loading="isSending"
                @click="showSendConfirm = true"
              />
            </div>

            <!-- Audience preview results -->
            <div
              v-if="audiencePreview"
              class="rounded-lg border border-n-weak bg-n-solid-1 p-3"
            >
              <p class="text-sm font-medium text-n-slate-12 mb-2">
                {{
                  t('CAMPAIGNS.AUDIENCE_COUNT', {
                    count: audiencePreview.count,
                  })
                }}
              </p>
              <div
                v-for="contact in audiencePreview.sample"
                :key="contact.id"
                class="flex items-center gap-2 py-1 text-sm text-n-slate-11"
              >
                <span class="i-lucide-user size-3.5" />
                <span>{{
                  contact.name || contact.email || contact.phone_number
                }}</span>
              </div>
              <p
                v-if="audiencePreview.count > audiencePreview.sample.length"
                class="text-xs text-n-slate-9 mt-1"
              >
                {{
                  t('CAMPAIGNS.AND_MORE', {
                    count:
                      audiencePreview.count - audiencePreview.sample.length,
                  })
                }}
              </p>
            </div>

            <!-- Send confirmation -->
            <div
              v-if="showSendConfirm"
              class="flex items-center gap-2 rounded-lg border border-n-ruby-6 bg-n-ruby-2 p-3"
            >
              <span class="i-lucide-alert-triangle size-4 text-n-ruby-11" />
              <p class="text-sm text-n-ruby-11 flex-1">
                {{ t('CAMPAIGNS.SEND_CONFIRM') }}
              </p>
              <Button
                size="sm"
                color="ruby"
                :label="t('CAMPAIGNS.CONFIRM_SEND')"
                @click="handleSendNow"
              />
              <Button
                variant="faded"
                color="slate"
                size="sm"
                :label="t('CAMPAIGNS.CANCEL')"
                @click="showSendConfirm = false"
              />
            </div>
          </div>

          <!-- Messages -->
          <div
            class="flex flex-col gap-4 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
          >
            <div class="flex items-center justify-between">
              <p class="text-sm font-semibold text-n-slate-12">
                {{ t('CAMPAIGNS.SECTIONS.MESSAGES') }}
              </p>
            </div>

            <div
              v-for="(block, idx) in form.messages"
              :key="idx"
              class="flex flex-col gap-2 rounded-xl border border-n-weak bg-n-solid-1 p-3"
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

            <div class="flex items-center gap-3 pt-2 border-t border-n-weak">
              <Switch v-model="form.enabled" />
              <label class="text-sm font-medium text-n-slate-12">
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
