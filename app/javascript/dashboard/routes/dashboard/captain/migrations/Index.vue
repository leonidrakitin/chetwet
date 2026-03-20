<script setup>
import { computed, ref, watch, onMounted, onUnmounted } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { createConsumer } from '@rails/actioncable';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import BulkMigrationsAPI from 'dashboard/api/captain/bulkMigrations';
import CaptainInboxes from 'dashboard/api/captain/inboxes';
import TelegramSessionsAPI from 'dashboard/api/telegramSessions';

const route = useRoute();
const { t } = useI18n();

const assistantId = computed(() => Number(route.params.assistantId));

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
  { value: 'telegram', labelKey: 'CAPTAIN.MIGRATIONS.SOURCE_TELEGRAM' },
  {
    value: 'telegram_personal',
    labelKey: 'CAPTAIN.MIGRATIONS.SOURCE_TELEGRAM_PERSONAL',
  },
  { value: 'whatsapp', labelKey: 'CAPTAIN.MIGRATIONS.SOURCE_WHATSAPP' },
  { value: 'vk', labelKey: 'CAPTAIN.MIGRATIONS.SOURCE_VK' },
  {
    value: 'vk_personal',
    labelKey: 'CAPTAIN.MIGRATIONS.SOURCE_VK_PERSONAL',
  },
];

const DATE_LIMIT_OPTIONS = [
  { value: '', labelKey: 'CAPTAIN.MIGRATIONS.DATE_LIMIT_ALL' },
  { value: 1, labelKey: 'CAPTAIN.MIGRATIONS.DATE_LIMIT_1' },
  { value: 2, labelKey: 'CAPTAIN.MIGRATIONS.DATE_LIMIT_2' },
  { value: 6, labelKey: 'CAPTAIN.MIGRATIONS.DATE_LIMIT_6' },
  { value: 12, labelKey: 'CAPTAIN.MIGRATIONS.DATE_LIMIT_12' },
];

const STATUS_BADGE_CLASSES = {
  pending: 'bg-amber-100 text-amber-800',
  processing: 'bg-blue-100 text-blue-700',
  completed: 'bg-green-100 text-green-700',
  failed: 'bg-red-100 text-red-700',
};

function statusBadgeClass(status) {
  return STATUS_BADGE_CLASSES[status] ?? 'bg-n-slate-6 text-n-slate-12';
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
    {
      channel: 'BulkMigrationChannel',
      migration_id: migrationId,
    },
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
    if (m.status === 'processing') {
      subscribeToMigration(m.id);
    } else {
      unsubscribeFromMigration(m.id);
    }
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

function onDragOver(e) {
  e.preventDefault();
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
      if (data.status === 'processing') {
        subscribeToMigration(data.id);
      }
      form.value.file = null;
      if (document.querySelector('input[type="file"]')) {
        document.querySelector('input[type="file"]').value = '';
      }
    })
    .catch(() => {
      createError.value = 'CAPTAIN.MIGRATIONS.ERROR_CREATE';
    })
    .finally(() => {
      isSubmitting.value = false;
    });
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

onMounted(() => {
  fetchMigrations();
  fetchInboxes();
  fetchTelegramSessions();
});

onUnmounted(() => {
  Object.keys(cableSubscriptions.value).forEach(id =>
    unsubscribeFromMigration(Number(id))
  );
});
</script>

<template>
  <PageLayout
    :header-title="$t('CAPTAIN.MIGRATIONS.HEADER')"
    :show-pagination-footer="false"
    :is-empty="false"
    :show-know-more="false"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
  >
    <template #body>
      <div class="flex flex-col gap-6">
        <p class="text-n-slate-11 text-sm">
          {{ $t('CAPTAIN.MIGRATIONS.DESCRIPTION') }}
        </p>

        <div
          class="rounded-lg border border-n-slate-8 bg-n-surface-2 p-4 flex flex-col gap-4"
        >
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <label class="mb-1 block text-sm font-medium text-n-slate-12">
                {{ $t('CAPTAIN.MIGRATIONS.SOURCE') }}
              </label>
              <select
                v-model="form.source"
                class="w-full rounded border border-n-slate-8 bg-n-surface-1 px-3 py-2 text-n-slate-12"
              >
                <option v-for="s in SOURCES" :key="s.value" :value="s.value">
                  {{ $t(s.labelKey) }}
                </option>
              </select>
            </div>
            <div>
              <label class="mb-1 block text-sm font-medium text-n-slate-12">
                {{ $t('CAPTAIN.MIGRATIONS.INBOX') }}
              </label>
              <select
                v-model="form.inboxId"
                class="w-full rounded border border-n-slate-8 bg-n-surface-1 px-3 py-2 text-n-slate-12"
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
          </div>

          <!-- Telegram session select (live source) -->
          <div v-if="isTelegramLive">
            <label class="mb-1 block text-sm font-medium text-n-slate-12">
              {{ $t('CAPTAIN.MIGRATIONS.TELEGRAM_SESSION') }}
            </label>
            <select
              v-model="form.telegramSessionId"
              class="w-full rounded border border-n-slate-8 bg-n-surface-1 px-3 py-2 text-n-slate-12"
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

          <!-- VK access token (vk_personal) -->
          <div v-if="isVkLive">
            <label class="mb-1 block text-sm font-medium text-n-slate-12">
              {{ $t('CAPTAIN.MIGRATIONS.VK_ACCESS_TOKEN') }}
            </label>
            <input
              v-model="form.vkAccessToken"
              type="password"
              class="w-full rounded border border-n-slate-8 bg-n-surface-1 px-3 py-2 text-n-slate-12"
              :placeholder="
                $t('CAPTAIN.MIGRATIONS.VK_ACCESS_TOKEN_PLACEHOLDER')
              "
            />
            <p class="mt-1 text-xs text-n-slate-11">
              {{ $t('CAPTAIN.MIGRATIONS.VK_ACCESS_TOKEN_HELP') }}
            </p>
          </div>

          <!-- File upload (file-based sources) -->
          <div v-if="!isLiveSource">
            <label class="mb-1 block text-sm font-medium text-n-slate-12">
              {{ $t('CAPTAIN.MIGRATIONS.FILE') }}
            </label>
            <div
              class="flex min-h-[80px] cursor-pointer items-center justify-center rounded border border-dashed border-n-slate-8 bg-n-surface-1 px-4 py-4 text-n-slate-11"
              @drop="onDrop"
              @dragover="onDragOver"
              @click="$refs.fileInput?.click()"
            >
              <input
                ref="fileInput"
                type="file"
                accept=".json,application/json"
                class="hidden"
                @change="onFileChange"
              />
              <span class="text-sm">
                {{
                  form.file
                    ? form.file.name
                    : $t('CAPTAIN.MIGRATIONS.FILE_PLACEHOLDER')
                }}
              </span>
            </div>
          </div>

          <!-- Date limit (live source) -->
          <div v-if="isLiveSource">
            <label class="mb-1 block text-sm font-medium text-n-slate-12">
              {{ $t('CAPTAIN.MIGRATIONS.DATE_LIMIT') }}
            </label>
            <select
              v-model="form.dateLimitMonths"
              class="w-full rounded border border-n-slate-8 bg-n-surface-1 px-3 py-2 text-n-slate-12"
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

          <div class="flex flex-wrap items-center gap-4">
            <label class="flex items-center gap-2">
              <input
                v-model="form.dryRun"
                type="checkbox"
                class="rounded border-n-slate-8"
              />
              <span class="text-sm text-n-slate-12">
                {{ $t('CAPTAIN.MIGRATIONS.DRY_RUN') }}
              </span>
            </label>
            <label class="flex items-center gap-2">
              <input
                v-model="form.includeGroups"
                type="checkbox"
                class="rounded border-n-slate-8"
              />
              <span class="text-sm text-n-slate-12">
                {{ $t('CAPTAIN.MIGRATIONS.INCLUDE_GROUPS') }}
              </span>
            </label>
          </div>

          <!-- File-based source options -->
          <div
            v-if="!isLiveSource"
            class="grid grid-cols-1 gap-4 sm:grid-cols-2"
          >
            <div>
              <label class="mb-1 block text-sm font-medium text-n-slate-12">
                {{ $t('CAPTAIN.MIGRATIONS.AGENT_EXTERNAL_ID') }}
              </label>
              <input
                v-model="form.agentExternalId"
                type="text"
                class="w-full rounded border border-n-slate-8 bg-n-surface-1 px-3 py-2 text-n-slate-12"
                :placeholder="
                  $t('CAPTAIN.MIGRATIONS.AGENT_EXTERNAL_ID_PLACEHOLDER')
                "
              />
            </div>
            <div>
              <label class="mb-1 block text-sm font-medium text-n-slate-12">
                {{ $t('CAPTAIN.MIGRATIONS.MAX_MESSAGES_PER_DIALOG') }}
              </label>
              <input
                v-model="form.maxMessagesPerDialog"
                type="number"
                min="1"
                class="w-full rounded border border-n-slate-8 bg-n-surface-1 px-3 py-2 text-n-slate-12"
              />
            </div>
          </div>

          <!-- Advanced options (live source) -->
          <div v-if="isLiveSource">
            <button
              type="button"
              class="text-sm text-n-slate-11 hover:text-n-slate-12"
              @click="showAdvanced = !showAdvanced"
            >
              {{ $t('CAPTAIN.MIGRATIONS.ADVANCED_OPTIONS') }}
              {{ showAdvanced ? '▲' : '▼' }}
            </button>
            <div
              v-if="showAdvanced"
              class="mt-3 grid grid-cols-1 gap-4 sm:grid-cols-2"
            >
              <div>
                <label class="mb-1 block text-sm font-medium text-n-slate-12">
                  {{ $t('CAPTAIN.MIGRATIONS.SESSION_GAP_MINUTES') }}
                </label>
                <input
                  v-model="form.sessionGapMinutes"
                  type="number"
                  min="1"
                  class="w-full rounded border border-n-slate-8 bg-n-surface-1 px-3 py-2 text-n-slate-12"
                />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium text-n-slate-12">
                  {{ $t('CAPTAIN.MIGRATIONS.MAX_CHATS') }}
                </label>
                <input
                  v-model="form.maxChats"
                  type="number"
                  min="1"
                  class="w-full rounded border border-n-slate-8 bg-n-surface-1 px-3 py-2 text-n-slate-12"
                />
              </div>
            </div>
          </div>

          <div v-if="createError" class="text-sm text-red-600">
            {{ $t(createError) }}
          </div>

          <div>
            <button
              type="button"
              class="rounded bg-woot-500 px-4 py-2 text-sm font-medium text-white hover:bg-woot-600 disabled:opacity-50"
              :disabled="isSubmitting"
              @click="submitMigration"
            >
              {{
                isSubmitting
                  ? $t('CAPTAIN.MIGRATIONS.STARTING')
                  : $t('CAPTAIN.MIGRATIONS.START')
              }}
            </button>
          </div>
        </div>

        <div>
          <h3 class="mb-3 text-base font-medium text-n-slate-12">
            {{ $t('CAPTAIN.MIGRATIONS.RECENT') }}
          </h3>
          <div
            v-if="isFetchingMigrations && !migrations.length"
            class="text-n-slate-11 text-sm"
          >
            {{ $t('CAPTAIN.MIGRATIONS.LOADING') }}
          </div>
          <div
            v-else-if="!migrations.length"
            class="rounded border border-n-slate-8 bg-n-surface-2 p-4 text-n-slate-11 text-sm"
          >
            {{ $t('CAPTAIN.MIGRATIONS.EMPTY_STATE') }}
          </div>
          <div v-else class="flex flex-col gap-3">
            <div
              v-for="m in migrations"
              :key="m.id"
              class="rounded-lg border border-n-slate-8 bg-n-surface-2 p-4"
            >
              <!-- Card header -->
              <div class="flex items-start justify-between gap-2 mb-3">
                <div class="flex items-center gap-2 flex-wrap">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ sourceLabel(m.source) }}
                  </span>
                  <span
                    v-if="m.dry_run"
                    class="text-xs px-1.5 py-0.5 bg-amber-100 text-amber-800 rounded font-medium"
                  >
                    {{ $t('CAPTAIN.MIGRATIONS.DRY_RUN_BADGE') }}
                  </span>
                </div>
                <div class="flex items-center gap-2 shrink-0">
                  <span class="text-xs text-n-slate-11">
                    {{
                      m.created_at
                        ? new Date(m.created_at).toLocaleString()
                        : '—'
                    }}
                  </span>
                  <span
                    :class="statusBadgeClass(m.status)"
                    class="text-xs px-2 py-0.5 rounded-full font-medium"
                  >
                    {{
                      $t(
                        'CAPTAIN.MIGRATIONS.STATUS_' +
                          (m.status || 'pending').toUpperCase()
                      )
                    }}
                  </span>
                </div>
              </div>

              <!-- processing -->
              <template v-if="m.status === 'processing'">
                <p class="text-xs text-n-slate-11 mb-1">
                  {{ $t('CAPTAIN.MIGRATIONS.PROCESSING_LABEL') }}
                </p>
                <div class="h-2 bg-n-slate-6 rounded-full overflow-hidden mb-1">
                  <div
                    class="h-full bg-woot-500 rounded-full transition-all"
                    :style="{ width: (m.progress_percent ?? 0) + '%' }"
                  />
                </div>
                <p class="text-xs text-n-slate-11">
                  {{
                    $t('CAPTAIN.MIGRATIONS.DIALOGS_PROGRESS', {
                      processed: m.processed ?? 0,
                      total: m.total_dialogs ?? '…',
                    })
                  }}
                  · {{ m.progress_percent ?? 0 }}%
                </p>
              </template>

              <!-- completed -->
              <template v-else-if="m.status === 'completed'">
                <div class="flex flex-wrap gap-2 mb-2">
                  <span
                    class="px-3 py-1.5 bg-n-surface-3 rounded-full text-xs text-n-slate-12"
                  >
                    {{ $t('CAPTAIN.MIGRATIONS.STEP_DIALOGS_FOUND') }}:
                    <span class="font-medium">
                      {{
                        m.report?.source_stats?.total_chats ??
                        m.report?.source_stats?.processed_chats ??
                        0
                      }}
                    </span>
                  </span>
                  <span
                    v-if="m.report?.preprocess_stats?.sessions_created"
                    class="px-3 py-1.5 bg-n-surface-3 rounded-full text-xs text-n-slate-12"
                  >
                    {{ $t('CAPTAIN.MIGRATIONS.STEP_SESSIONS') }}:
                    <span class="font-medium">
                      {{ m.report.preprocess_stats.sessions_created }}
                    </span>
                  </span>
                  <span
                    class="px-3 py-1.5 bg-n-surface-3 rounded-full text-xs text-n-slate-12"
                  >
                    {{ $t('CAPTAIN.MIGRATIONS.STEP_AFTER_CLEANING') }}:
                    <span class="font-medium">
                      {{ m.report?.preprocess_stats?.ready_for_import ?? 0 }}
                    </span>
                  </span>
                  <span
                    class="px-3 py-1.5 bg-n-surface-3 rounded-full text-xs text-n-slate-12"
                  >
                    {{ $t('CAPTAIN.MIGRATIONS.STEP_IMPORTED') }}:
                    <span class="font-medium">
                      {{ m.report?.import_stats?.imported ?? 0 }}
                    </span>
                  </span>
                  <span
                    class="px-3 py-1.5 bg-n-surface-3 rounded-full text-xs text-n-slate-12"
                  >
                    {{ $t('CAPTAIN.MIGRATIONS.STEP_FAQS') }}:
                    <span class="font-medium">
                      {{ m.report?.total_faqs_generated ?? 0 }}
                    </span>
                  </span>
                </div>
                <p v-if="m.report?.summary" class="text-xs text-n-slate-11">
                  {{ m.report.summary }}
                </p>
              </template>

              <!-- failed -->
              <template v-else-if="m.status === 'failed'">
                <p class="text-xs text-red-600">
                  {{ m.report?.error || $t('CAPTAIN.MIGRATIONS.FAILED_LABEL') }}
                </p>
              </template>

              <!-- pending -->
              <template v-else>
                <p class="text-xs text-n-slate-11">
                  {{ $t('CAPTAIN.MIGRATIONS.PENDING_LABEL') }}
                </p>
              </template>
            </div>
          </div>
        </div>
      </div>
    </template>
  </PageLayout>
</template>
