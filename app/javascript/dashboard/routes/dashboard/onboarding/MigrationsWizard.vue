<script setup>
import { computed, ref, watch, onMounted, onUnmounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { createConsumer } from '@rails/actioncable';
import { useStore } from 'dashboard/composables/store';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import BulkMigrationsAPI from 'dashboard/api/captain/bulkMigrations';
import CaptainInboxes from 'dashboard/api/captain/inboxes';
import TelegramSessionsAPI from 'dashboard/api/telegramSessions';
import {
  setAccountScopedPathOverride,
  clearAccountScopedPathOverride,
} from 'dashboard/api/ApiClient';

const props = defineProps({
  embedded: {
    type: Boolean,
    default: false,
  },
});

const router = useRouter();
const route = useRoute();
const { t } = useI18n();
const store = useStore();

// Derive assistantId from query param or last active assistant
const assistants = computed(
  () => store.getters['captainAssistants/getRecords']
);
const assistantId = computed(() => {
  const qid = Number(route.query.assistantId);
  if (qid) return qid;
  if (assistants.value.length) return assistants.value[0].id;
  return null;
});

const VIEW_FORM = 'form';
const VIEW_LIST = 'list';
const activeView = ref(VIEW_FORM);

const form = ref({
  source: 'telegram',
  inboxId: '',
  file: null,
  dryRun: false,
  agentExternalId: '',
  includeGroups: false,
  maxMessagesPerDialog: '',
  telegramSessionId: '',
  dateLimitMonths: '',
  sessionGapMinutes: '',
  maxChats: '',
  vkAccessToken: '',
});
const isSubmitting = ref(false);
const createError = ref('');
const showAdvanced = ref(false);

const migrations = ref([]);
const isFetchingMigrations = ref(false);

const inboxes = ref([]);
const isFetchingInboxes = ref(false);

const telegramSessions = ref([]);
const isFetchingSessions = ref(false);

const cableSubscriptions = ref({});

const isLiveSource = computed(() =>
  ['telegram_personal', 'vk_personal'].includes(form.value.source)
);
const isTelegramLive = computed(
  () => form.value.source === 'telegram_personal'
);
const isVkLive = computed(() => form.value.source === 'vk_personal');

const SOURCES = [
  {
    value: 'telegram',
    labelKey: 'CAPTAIN.MIGRATIONS.SOURCE_TELEGRAM',
    icon: 'i-lucide-send',
  },
  {
    value: 'telegram_personal',
    labelKey: 'CAPTAIN.MIGRATIONS.SOURCE_TELEGRAM_PERSONAL',
    icon: 'i-lucide-user',
  },
  {
    value: 'whatsapp',
    labelKey: 'CAPTAIN.MIGRATIONS.SOURCE_WHATSAPP',
    icon: 'i-lucide-message-circle',
  },
  {
    value: 'vk',
    labelKey: 'CAPTAIN.MIGRATIONS.SOURCE_VK',
    icon: 'i-lucide-hash',
  },
  {
    value: 'vk_personal',
    labelKey: 'CAPTAIN.MIGRATIONS.SOURCE_VK_PERSONAL',
    icon: 'i-lucide-user',
  },
];

const DATE_LIMIT_OPTIONS = [
  { value: '', labelKey: 'CAPTAIN.MIGRATIONS.DATE_LIMIT_ALL' },
  { value: 1, labelKey: 'CAPTAIN.MIGRATIONS.DATE_LIMIT_1' },
  { value: 2, labelKey: 'CAPTAIN.MIGRATIONS.DATE_LIMIT_2' },
  { value: 6, labelKey: 'CAPTAIN.MIGRATIONS.DATE_LIMIT_6' },
  { value: 12, labelKey: 'CAPTAIN.MIGRATIONS.DATE_LIMIT_12' },
];

const STATUS_CONFIG = {
  pending: {
    badge:
      'bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400',
    icon: 'i-lucide-clock',
  },
  processing: {
    badge: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400',
    icon: 'i-lucide-loader-circle',
  },
  completed: {
    badge:
      'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
    icon: 'i-lucide-check-circle',
  },
  failed: {
    badge: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400',
    icon: 'i-lucide-x-circle',
  },
};

function statusBadgeClass(status) {
  return STATUS_CONFIG[status]?.badge ?? 'bg-n-slate-6 text-n-slate-12';
}

function statusIcon(status) {
  return STATUS_CONFIG[status]?.icon ?? 'i-lucide-circle';
}

function sourceLabel(source) {
  const found = SOURCES.find(s => s.value === source);
  return found ? t(found.labelKey) : source;
}

function fetchMigrations() {
  isFetchingMigrations.value = true;
  BulkMigrationsAPI.get()
    .then(({ data }) => {
      migrations.value = Array.isArray(data) ? data : [];
    })
    .catch(() => {
      migrations.value = [];
    })
    .finally(() => {
      isFetchingMigrations.value = false;
    });
}

function fetchInboxes() {
  if (!assistantId.value) return;
  isFetchingInboxes.value = true;
  CaptainInboxes.get({ assistantId: assistantId.value })
    .then(({ data }) => {
      inboxes.value = Array.isArray(data?.payload) ? data.payload : [];
      if (inboxes.value.length && !form.value.inboxId) {
        form.value.inboxId = String(inboxes.value[0].id);
      }
    })
    .catch(() => {
      inboxes.value = [];
    })
    .finally(() => {
      isFetchingInboxes.value = false;
    });
}

function fetchTelegramSessions() {
  isFetchingSessions.value = true;
  TelegramSessionsAPI.getAll()
    .then(({ data }) => {
      telegramSessions.value = Array.isArray(data) ? data : [];
    })
    .catch(() => {
      telegramSessions.value = [];
    })
    .finally(() => {
      isFetchingSessions.value = false;
    });
}

function subscribeToMigration(migrationId) {
  if (cableSubscriptions.value[migrationId]) return;
  const websocketURL = window.chatwootConfig?.websocketURL || '';
  const cableURL = websocketURL ? `${websocketURL}/cable` : '/cable';
  const consumer = createConsumer(cableURL);
  const subscription = consumer.subscriptions.create(
    { channel: 'BulkMigrationChannel', migration_id: migrationId },
    {
      received(data) {
        const idx = migrations.value.findIndex(m => m.id === migrationId);
        if (idx === -1) return;
        if (data.processed !== undefined) {
          migrations.value[idx] = {
            ...migrations.value[idx],
            processed: data.processed,
            total_dialogs: data.total ?? migrations.value[idx].total_dialogs,
            progress_percent: data.progress ?? 0,
            status: data.status || migrations.value[idx].status,
          };
        }
      },
    }
  );
  cableSubscriptions.value[migrationId] = { consumer, subscription };
}

function unsubscribeFromMigration(migrationId) {
  const sub = cableSubscriptions.value[migrationId];
  if (sub) {
    sub.subscription.unsubscribe();
    sub.consumer.disconnect();
    delete cableSubscriptions.value[migrationId];
  }
}

function ensureSubscriptions() {
  migrations.value.forEach(m => {
    if (m.status === 'processing') subscribeToMigration(m.id);
    else unsubscribeFromMigration(m.id);
  });
}

function onFileChange(e) {
  const file = e.target.files?.[0];
  form.value.file = file || null;
}

function onDrop(e) {
  e.preventDefault();
  const file = e.dataTransfer?.files?.[0];
  if (
    file &&
    (file.type === 'application/json' || file.name.endsWith('.json'))
  ) {
    form.value.file = file;
  }
}

function submitFileMigration() {
  const fd = new FormData();
  fd.append('bulk_migration[source]', form.value.source);
  fd.append('bulk_migration[captain_assistant_id]', assistantId.value);
  fd.append('bulk_migration[inbox_id]', form.value.inboxId);
  fd.append('bulk_migration[file]', form.value.file);
  fd.append('bulk_migration[dry_run]', form.value.dryRun ? '1' : '0');
  if (form.value.agentExternalId) {
    fd.append('bulk_migration[agent_external_id]', form.value.agentExternalId);
  }
  fd.append(
    'bulk_migration[include_groups]',
    form.value.includeGroups ? '1' : '0'
  );
  if (form.value.maxMessagesPerDialog) {
    fd.append(
      'bulk_migration[max_messages_per_dialog]',
      form.value.maxMessagesPerDialog
    );
  }
  return BulkMigrationsAPI.create(fd);
}

function submitLiveMigration() {
  const config = {};
  if (form.value.dateLimitMonths)
    config.date_limit_months = Number(form.value.dateLimitMonths);
  if (form.value.sessionGapMinutes)
    config.session_gap_minutes = Number(form.value.sessionGapMinutes);
  if (form.value.maxChats) config.max_chats = Number(form.value.maxChats);

  const payload = {
    source: form.value.source,
    captain_assistant_id: assistantId.value,
    inbox_id: form.value.inboxId,
    dry_run: form.value.dryRun,
    include_groups: form.value.includeGroups,
    config,
  };

  if (isTelegramLive.value) {
    payload.telegram_session_id = form.value.telegramSessionId;
  } else if (isVkLive.value) {
    config.vk_access_token = form.value.vkAccessToken;
  }

  return BulkMigrationsAPI.createLive(payload);
}

function submitMigration() {
  createError.value = '';

  if (isLiveSource.value) {
    if (isTelegramLive.value && !form.value.telegramSessionId) {
      createError.value = 'CAPTAIN.MIGRATIONS.ERROR_SESSION_REQUIRED';
      return;
    }
    if (isVkLive.value && !form.value.vkAccessToken) {
      createError.value = 'CAPTAIN.MIGRATIONS.ERROR_VK_TOKEN_REQUIRED';
      return;
    }
  } else if (!form.value.file) {
    createError.value = 'CAPTAIN.MIGRATIONS.ERROR_FILE_REQUIRED';
    return;
  }

  if (!form.value.inboxId) {
    createError.value = 'CAPTAIN.MIGRATIONS.ERROR_INBOX_REQUIRED';
    return;
  }

  isSubmitting.value = true;

  const apiCall = isLiveSource.value
    ? submitLiveMigration()
    : submitFileMigration();

  apiCall
    .then(({ data }) => {
      migrations.value = [data, ...migrations.value];
      if (data.status === 'processing') subscribeToMigration(data.id);
      form.value.file = null;
      if (document.querySelector('input[type="file"]')) {
        document.querySelector('input[type="file"]').value = '';
      }
      activeView.value = VIEW_LIST;
    })
    .catch(() => {
      createError.value = 'CAPTAIN.MIGRATIONS.ERROR_CREATE';
    })
    .finally(() => {
      isSubmitting.value = false;
    });
}

function resolveAccountId() {
  const fromRoute = Number(route.params.accountId);
  if (fromRoute) return fromRoute;
  return store.getters.getCurrentUser?.account_id;
}

function applyAccountScopedApiOverride() {
  const id = resolveAccountId();
  if (id) setAccountScopedPathOverride(id);
}

function goToDashboard() {
  const id = resolveAccountId();
  if (id) {
    router.push({ name: 'home', params: { accountId: String(id) } });
  }
}

watch(
  () => migrations.value.map(m => ({ id: m.id, status: m.status })),
  () => ensureSubscriptions(),
  { deep: true }
);

watch(assistantId, () => {
  fetchInboxes();
  form.value.inboxId = '';
});

onMounted(async () => {
  applyAccountScopedApiOverride();
  await store.dispatch('captainAssistants/get');
  fetchMigrations();
  fetchInboxes();
  fetchTelegramSessions();
});

onUnmounted(() => {
  clearAccountScopedPathOverride();
  Object.keys(cableSubscriptions.value).forEach(id =>
    unsubscribeFromMigration(Number(id))
  );
});
</script>

<template>
  <div
    :class="
      props.embedded
        ? 'w-full'
        : 'fixed inset-0 z-50 flex items-center justify-center bg-gradient-to-br from-n-brand/5 via-n-background to-n-brand/10 dark:from-n-background dark:via-n-solid-1 dark:to-n-background p-4'
    "
  >
    <div
      :class="
        props.embedded
          ? 'w-full flex flex-col min-h-0 overflow-hidden'
          : 'w-full max-w-2xl mx-auto flex flex-col bg-white dark:bg-n-solid-2 rounded-2xl shadow-lg ring-1 ring-n-container/50 dark:ring-n-container overflow-hidden'
      "
    >
      <!-- Header -->
      <div
        class="flex items-center px-6 pt-5 pb-0"
        :class="props.embedded ? 'justify-start' : 'justify-between'"
      >
        <div class="flex items-center gap-2">
          <!-- Tab: New migration -->
          <button
            class="px-3 py-1.5 text-sm font-medium rounded-lg transition-colors"
            :class="
              activeView === 'form'
                ? 'bg-n-brand/10 text-n-brand'
                : 'text-n-slate-10 hover:text-n-slate-12'
            "
            @click="activeView = 'form'"
          >
            {{ $t('CAPTAIN.MIGRATIONS.START') }}
          </button>
          <!-- Tab: History -->
          <button
            class="px-3 py-1.5 text-sm font-medium rounded-lg transition-colors flex items-center gap-1.5"
            :class="
              activeView === 'list'
                ? 'bg-n-brand/10 text-n-brand'
                : 'text-n-slate-10 hover:text-n-slate-12'
            "
            @click="activeView = 'list'"
          >
            {{ $t('CAPTAIN.MIGRATIONS.RECENT') }}
            <span
              v-if="migrations.length"
              class="text-xs px-1.5 py-0.5 rounded-full bg-n-slate-4 text-n-slate-11"
            >
              {{ migrations.length }}
            </span>
          </button>
        </div>
        <button
          v-if="!props.embedded"
          class="text-sm text-n-slate-10 hover:text-n-slate-12 transition-colors"
          @click="goToDashboard"
        >
          {{ $t('ONBOARDING.SKIP') }}
        </button>
      </div>

      <!-- Divider -->
      <div class="h-px bg-n-container mx-6 mt-4" />

      <!-- Content -->
      <div
        class="px-8 py-6 overflow-y-auto"
        :class="props.embedded ? 'max-h-[min(60vh,28rem)]' : 'max-h-[80vh]'"
      >
        <!-- ─── FORM VIEW ─── -->
        <Transition
          enter-active-class="transition duration-200 ease-out"
          enter-from-class="translate-x-4 opacity-0"
          enter-to-class="translate-x-0 opacity-100"
          leave-active-class="transition duration-150 ease-in"
          leave-from-class="translate-x-0 opacity-100"
          leave-to-class="-translate-x-4 opacity-0"
          mode="out-in"
        >
          <div
            v-if="activeView === 'form'"
            key="form"
            class="flex flex-col gap-5"
          >
            <!-- Title block -->
            <div class="flex flex-col items-center text-center pb-2">
              <div
                class="flex items-center justify-center w-14 h-14 rounded-2xl bg-n-brand/10 mb-4"
              >
                <Icon icon="i-lucide-database" class="size-7 text-n-brand" />
              </div>
              <h1 class="text-xl font-bold text-n-slate-12 mb-1">
                {{ $t('CAPTAIN.MIGRATIONS.HEADER') }}
              </h1>
              <p class="text-sm text-n-slate-10 max-w-md">
                {{ $t('CAPTAIN.MIGRATIONS.DESCRIPTION') }}
              </p>
            </div>

            <!-- Source selector -->
            <div>
              <p
                class="text-xs font-medium text-n-slate-11 mb-2 uppercase tracking-wide"
              >
                {{ $t('CAPTAIN.MIGRATIONS.SOURCE') }}
              </p>
              <div class="grid grid-cols-5 gap-2">
                <button
                  v-for="s in SOURCES"
                  :key="s.value"
                  class="flex flex-col items-center gap-1.5 px-2 py-2.5 rounded-xl text-xs font-medium transition-all outline outline-1 -outline-offset-1"
                  :class="
                    form.source === s.value
                      ? 'bg-n-brand/10 text-n-brand outline-n-brand/30'
                      : 'bg-white dark:bg-n-solid-3 text-n-slate-11 outline-n-container hover:outline-n-brand/30'
                  "
                  @click="form.source = s.value"
                >
                  <Icon :icon="s.icon" class="size-4" />
                  {{ $t(s.labelKey) }}
                </button>
              </div>
            </div>

            <!-- Inbox select -->
            <div>
              <p
                class="text-xs font-medium text-n-slate-11 mb-2 uppercase tracking-wide"
              >
                {{ $t('CAPTAIN.MIGRATIONS.INBOX') }}
              </p>
              <select
                v-model="form.inboxId"
                class="w-full rounded-xl border border-n-border-glass-soft bg-n-glass-soft px-3 py-2.5 text-sm text-n-text-display outline-none focus:ring-2 focus:ring-n-brand/30 transition-all"
                :disabled="isFetchingInboxes || !inboxes.length"
              >
                <option value="">
                  {{ $t('CAPTAIN.MIGRATIONS.INBOX_PLACEHOLDER') }}
                </option>
                <option
                  v-for="inbox in inboxes"
                  :key="inbox.id"
                  :value="String(inbox.id)"
                >
                  {{ inbox.name || inbox.id }}
                </option>
              </select>
            </div>

            <!-- Telegram personal: session select -->
            <div v-if="isTelegramLive">
              <p
                class="text-xs font-medium text-n-slate-11 mb-2 uppercase tracking-wide"
              >
                {{ $t('CAPTAIN.MIGRATIONS.TELEGRAM_SESSION') }}
              </p>
              <select
                v-model="form.telegramSessionId"
                class="w-full rounded-xl border border-n-border-glass-soft bg-n-glass-soft px-3 py-2.5 text-sm text-n-text-display outline-none focus:ring-2 focus:ring-n-brand/30 transition-all"
                :disabled="isFetchingSessions || !telegramSessions.length"
              >
                <option value="">
                  {{ $t('CAPTAIN.MIGRATIONS.TELEGRAM_SESSION_PLACEHOLDER') }}
                </option>
                <option
                  v-for="session in telegramSessions"
                  :key="session.id"
                  :value="String(session.id)"
                >
                  {{ session.phone_number || session.id }}
                </option>
              </select>
            </div>

            <!-- VK personal: access token -->
            <div v-if="isVkLive">
              <NextInput
                v-model="form.vkAccessToken"
                type="password"
                :label="$t('CAPTAIN.MIGRATIONS.VK_ACCESS_TOKEN')"
                :placeholder="
                  $t('CAPTAIN.MIGRATIONS.VK_ACCESS_TOKEN_PLACEHOLDER')
                "
              />
              <p class="mt-1 text-xs text-n-slate-10">
                {{ $t('CAPTAIN.MIGRATIONS.VK_ACCESS_TOKEN_HELP') }}
              </p>
            </div>

            <!-- File upload (file-based) -->
            <div v-if="!isLiveSource">
              <p
                class="text-xs font-medium text-n-slate-11 mb-2 uppercase tracking-wide"
              >
                {{ $t('CAPTAIN.MIGRATIONS.FILE') }}
              </p>
              <div
                class="flex min-h-[90px] cursor-pointer flex-col items-center justify-center gap-2 rounded-xl border-2 border-dashed transition-colors"
                :class="
                  form.file
                    ? 'border-n-brand/40 bg-n-brand/5'
                    : 'border-n-border-glass-soft bg-n-glass-soft hover:border-n-brand/30'
                "
                @drop="onDrop"
                @dragover.prevent
                @click="$refs.fileInput?.click()"
              >
                <input
                  ref="fileInput"
                  type="file"
                  accept=".json,application/json"
                  class="hidden"
                  @change="onFileChange"
                />
                <Icon
                  :icon="
                    form.file ? 'i-lucide-file-check' : 'i-lucide-upload-cloud'
                  "
                  class="size-6"
                  :class="form.file ? 'text-n-brand' : 'text-n-slate-9'"
                />
                <span
                  class="text-sm"
                  :class="
                    form.file ? 'text-n-brand font-medium' : 'text-n-slate-10'
                  "
                >
                  {{
                    form.file
                      ? form.file.name
                      : $t('CAPTAIN.MIGRATIONS.FILE_PLACEHOLDER')
                  }}
                </span>
              </div>
            </div>

            <!-- Date limit (live) -->
            <div v-if="isLiveSource">
              <p
                class="text-xs font-medium text-n-slate-11 mb-2 uppercase tracking-wide"
              >
                {{ $t('CAPTAIN.MIGRATIONS.DATE_LIMIT') }}
              </p>
              <select
                v-model="form.dateLimitMonths"
                class="w-full rounded-xl border border-n-border-glass-soft bg-n-glass-soft px-3 py-2.5 text-sm text-n-text-display outline-none focus:ring-2 focus:ring-n-brand/30 transition-all"
              >
                <option
                  v-for="opt in DATE_LIMIT_OPTIONS"
                  :key="opt.value"
                  :value="opt.value"
                >
                  {{ $t(opt.labelKey) }}
                </option>
              </select>
            </div>

            <!-- Checkboxes -->
            <div class="flex flex-wrap items-center gap-4">
              <label class="flex items-center gap-2 cursor-pointer select-none">
                <div
                  class="w-4 h-4 rounded border flex items-center justify-center transition-colors"
                  :class="
                    form.dryRun
                      ? 'bg-n-brand border-n-brand'
                      : 'border-n-border-glass-soft bg-n-glass-soft'
                  "
                  @click="form.dryRun = !form.dryRun"
                >
                  <Icon
                    v-if="form.dryRun"
                    icon="i-lucide-check"
                    class="size-3 text-white"
                  />
                </div>
                <span class="text-sm text-n-slate-11">
                  {{ $t('CAPTAIN.MIGRATIONS.DRY_RUN') }}
                </span>
              </label>
              <label class="flex items-center gap-2 cursor-pointer select-none">
                <div
                  class="w-4 h-4 rounded border flex items-center justify-center transition-colors"
                  :class="
                    form.includeGroups
                      ? 'bg-n-brand border-n-brand'
                      : 'border-n-border-glass-soft bg-n-glass-soft'
                  "
                  @click="form.includeGroups = !form.includeGroups"
                >
                  <Icon
                    v-if="form.includeGroups"
                    icon="i-lucide-check"
                    class="size-3 text-white"
                  />
                </div>
                <span class="text-sm text-n-slate-11">
                  {{ $t('CAPTAIN.MIGRATIONS.INCLUDE_GROUPS') }}
                </span>
              </label>
            </div>

            <!-- File-based extra options -->
            <div
              v-if="!isLiveSource"
              class="grid grid-cols-1 gap-4 sm:grid-cols-2"
            >
              <NextInput
                v-model="form.agentExternalId"
                :label="$t('CAPTAIN.MIGRATIONS.AGENT_EXTERNAL_ID')"
                :placeholder="
                  $t('CAPTAIN.MIGRATIONS.AGENT_EXTERNAL_ID_PLACEHOLDER')
                "
              />
              <NextInput
                v-model="form.maxMessagesPerDialog"
                type="number"
                :label="$t('CAPTAIN.MIGRATIONS.MAX_MESSAGES_PER_DIALOG')"
                placeholder="—"
              />
            </div>

            <!-- Advanced options (live) -->
            <div v-if="isLiveSource">
              <button
                type="button"
                class="flex items-center gap-1.5 text-sm text-n-slate-10 hover:text-n-slate-12 transition-colors"
                @click="showAdvanced = !showAdvanced"
              >
                <Icon
                  :icon="
                    showAdvanced
                      ? 'i-lucide-chevron-up'
                      : 'i-lucide-chevron-down'
                  "
                  class="size-4"
                />
                {{ $t('CAPTAIN.MIGRATIONS.ADVANCED_OPTIONS') }}
              </button>
              <div
                v-if="showAdvanced"
                class="mt-3 grid grid-cols-1 gap-4 sm:grid-cols-2"
              >
                <NextInput
                  v-model="form.sessionGapMinutes"
                  type="number"
                  :label="$t('CAPTAIN.MIGRATIONS.SESSION_GAP_MINUTES')"
                  placeholder="—"
                />
                <NextInput
                  v-model="form.maxChats"
                  type="number"
                  :label="$t('CAPTAIN.MIGRATIONS.MAX_CHATS')"
                  placeholder="—"
                />
              </div>
            </div>

            <!-- Error -->
            <div
              v-if="createError"
              class="flex items-center gap-2 rounded-xl bg-red-50 dark:bg-red-900/20 px-4 py-3 text-sm text-red-600 dark:text-red-400"
            >
              <Icon icon="i-lucide-alert-circle" class="size-4 shrink-0" />
              {{ $t(createError) }}
            </div>

            <!-- Submit -->
            <NextButton
              class="w-full"
              :label="
                isSubmitting
                  ? $t('CAPTAIN.MIGRATIONS.STARTING')
                  : $t('CAPTAIN.MIGRATIONS.START')
              "
              icon="i-lucide-play"
              :is-loading="isSubmitting"
              :disabled="isSubmitting"
              @click="submitMigration"
            />
          </div>

          <!-- ─── LIST VIEW ─── -->
          <div v-else key="list" class="flex flex-col gap-4">
            <!-- Title -->
            <div class="flex flex-col items-center text-center pb-1">
              <div
                class="flex items-center justify-center w-14 h-14 rounded-2xl bg-n-brand/10 mb-4"
              >
                <Icon icon="i-lucide-history" class="size-7 text-n-brand" />
              </div>
              <h1 class="text-xl font-bold text-n-slate-12 mb-1">
                {{ $t('CAPTAIN.MIGRATIONS.RECENT') }}
              </h1>
            </div>

            <!-- Loading -->
            <div
              v-if="isFetchingMigrations && !migrations.length"
              class="flex items-center justify-center py-8 text-n-slate-10 text-sm gap-2"
            >
              <Icon icon="i-lucide-loader-circle" class="size-4 animate-spin" />
              {{ $t('CAPTAIN.MIGRATIONS.LOADING') }}
            </div>

            <!-- Empty state -->
            <div
              v-else-if="!migrations.length"
              class="flex flex-col items-center justify-center py-8 text-center gap-3"
            >
              <div
                class="flex items-center justify-center w-12 h-12 rounded-2xl bg-n-slate-3"
              >
                <Icon icon="i-lucide-inbox" class="size-6 text-n-slate-9" />
              </div>
              <p class="text-sm text-n-slate-10">
                {{ $t('CAPTAIN.MIGRATIONS.EMPTY_STATE') }}
              </p>
              <NextButton
                variant="ghost"
                color="slate"
                sm
                :label="$t('CAPTAIN.MIGRATIONS.START')"
                @click="activeView = 'form'"
              />
            </div>

            <!-- Migration cards -->
            <div v-else class="flex flex-col gap-3">
              <div
                v-for="m in migrations"
                :key="m.id"
                class="rounded-xl border border-n-border-glass-soft bg-n-glass-soft p-4 transition-all hover:border-n-slate-6"
              >
                <!-- Card header -->
                <div class="flex items-start justify-between gap-2 mb-3">
                  <div class="flex items-center gap-2 flex-wrap">
                    <span class="text-sm font-semibold text-n-slate-12">
                      {{ sourceLabel(m.source) }}
                    </span>
                    <span
                      v-if="m.dry_run"
                      class="text-xs px-1.5 py-0.5 bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400 rounded-md font-medium"
                    >
                      {{ $t('CAPTAIN.MIGRATIONS.DRY_RUN_BADGE') }}
                    </span>
                  </div>
                  <div class="flex items-center gap-2 shrink-0">
                    <span class="text-xs text-n-slate-9">
                      {{
                        m.created_at
                          ? new Date(m.created_at).toLocaleString()
                          : $t('CAPTAIN.MIGRATIONS.TABLE_NA')
                      }}
                    </span>
                    <span
                      :class="statusBadgeClass(m.status)"
                      class="flex items-center gap-1 text-xs px-2 py-0.5 rounded-full font-medium"
                    >
                      <Icon
                        :icon="statusIcon(m.status)"
                        class="size-3"
                        :class="m.status === 'processing' ? 'animate-spin' : ''"
                      />
                      {{
                        $t(
                          'CAPTAIN.MIGRATIONS.STATUS_' +
                            (m.status || 'pending').toUpperCase()
                        )
                      }}
                    </span>
                  </div>
                </div>

                <!-- Processing -->
                <template v-if="m.status === 'processing'">
                  <p class="text-xs text-n-slate-10 mb-2">
                    {{ $t('CAPTAIN.MIGRATIONS.PROCESSING_LABEL') }}
                  </p>
                  <div
                    class="h-1.5 bg-n-slate-4 rounded-full overflow-hidden mb-1.5"
                  >
                    <div
                      class="h-full bg-n-brand rounded-full transition-all duration-500"
                      :style="{ width: (m.progress_percent ?? 0) + '%' }"
                    />
                  </div>
                  <p class="text-xs text-n-slate-10">
                    {{
                      $t('CAPTAIN.MIGRATIONS.DIALOGS_PROGRESS_LINE', {
                        processed: m.processed ?? 0,
                        total:
                          m.total_dialogs ?? $t('CAPTAIN.MIGRATIONS.TABLE_NA'),
                        pct: m.progress_percent ?? 0,
                      })
                    }}
                  </p>
                </template>

                <!-- Completed -->
                <template v-else-if="m.status === 'completed'">
                  <div class="flex flex-wrap gap-2">
                    <span
                      class="flex items-center gap-1 px-2.5 py-1 bg-n-surface-3 rounded-lg text-xs text-n-slate-11"
                    >
                      {{
                        $t('CAPTAIN.MIGRATIONS.DIALOG_STAT_FOUND', {
                          count:
                            m.report?.source_stats?.total_chats ??
                            m.report?.source_stats?.processed_chats ??
                            0,
                        })
                      }}
                    </span>
                    <span
                      v-if="m.report?.preprocess_stats?.sessions_created"
                      class="flex items-center gap-1 px-2.5 py-1 bg-n-surface-3 rounded-lg text-xs text-n-slate-11"
                    >
                      {{
                        $t('CAPTAIN.MIGRATIONS.DIALOG_STAT_SESSIONS', {
                          count: m.report.preprocess_stats.sessions_created,
                        })
                      }}
                    </span>
                    <span
                      class="flex items-center gap-1 px-2.5 py-1 bg-n-surface-3 rounded-lg text-xs text-n-slate-11"
                    >
                      {{
                        $t('CAPTAIN.MIGRATIONS.DIALOG_STAT_CLEANED', {
                          count:
                            m.report?.preprocess_stats?.ready_for_import ?? 0,
                        })
                      }}
                    </span>
                    <span
                      class="flex items-center gap-1 px-2.5 py-1 bg-n-surface-3 rounded-lg text-xs text-n-slate-11"
                    >
                      {{
                        $t('CAPTAIN.MIGRATIONS.DIALOG_STAT_IMPORTED', {
                          count: m.report?.import_stats?.imported ?? 0,
                        })
                      }}
                    </span>
                    <span
                      class="flex items-center gap-1 px-2.5 py-1 bg-n-surface-3 rounded-lg text-xs text-n-slate-11"
                    >
                      {{
                        $t('CAPTAIN.MIGRATIONS.DIALOG_STAT_FAQS', {
                          count: m.report?.total_faqs_generated ?? 0,
                        })
                      }}
                    </span>
                  </div>
                  <p
                    v-if="m.report?.summary"
                    class="mt-2 text-xs text-n-slate-10"
                  >
                    {{ m.report.summary }}
                  </p>
                </template>

                <!-- Failed -->
                <template v-else-if="m.status === 'failed'">
                  <div
                    class="flex items-center gap-2 text-xs text-red-600 dark:text-red-400"
                  >
                    <Icon
                      icon="i-lucide-alert-triangle"
                      class="size-3.5 shrink-0"
                    />
                    {{
                      m.report?.error || $t('CAPTAIN.MIGRATIONS.FAILED_LABEL')
                    }}
                  </div>
                </template>

                <!-- Pending -->
                <template v-else>
                  <p class="text-xs text-n-slate-10 flex items-center gap-1.5">
                    <Icon icon="i-lucide-clock" class="size-3.5" />
                    {{ $t('CAPTAIN.MIGRATIONS.PENDING_LABEL') }}
                  </p>
                </template>
              </div>
            </div>
          </div>
        </Transition>
      </div>

      <!-- Footer -->
      <div
        v-if="!props.embedded"
        class="flex items-center justify-between px-8 pb-6 pt-2"
      >
        <NextButton
          variant="ghost"
          color="slate"
          sm
          :label="$t('ONBOARDING.BACK')"
          icon="i-lucide-arrow-left"
          @click="goToDashboard"
        />
        <NextButton
          sm
          :label="$t('ONBOARDING.COMPLETE_STEP.GO_TO_DASHBOARD')"
          icon="i-lucide-arrow-right"
          @click="goToDashboard"
        />
      </div>
    </div>
  </div>
</template>
