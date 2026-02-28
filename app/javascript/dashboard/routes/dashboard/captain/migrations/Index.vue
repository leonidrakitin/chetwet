<script setup>
import { computed, ref, watch, onMounted, onUnmounted } from 'vue';
import { useRoute } from 'vue-router';
import { createConsumer } from '@rails/actioncable';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import BulkMigrationsAPI from 'dashboard/api/captain/bulkMigrations';
import CaptainInboxes from 'dashboard/api/captain/inboxes';

const route = useRoute();

const assistantId = computed(() => Number(route.params.assistantId));

const form = ref({
  source: 'telegram',
  inboxId: '',
  file: null,
  dryRun: false,
  agentExternalId: '',
  includeGroups: false,
  maxMessagesPerDialog: '',
});
const isSubmitting = ref(false);
const createError = ref('');

const migrations = ref([]);
const isFetchingMigrations = ref(false);

const inboxes = ref([]);
const isFetchingInboxes = ref(false);

const cableSubscriptions = ref({});

const SOURCES = [
  { value: 'telegram', labelKey: 'CAPTAIN.MIGRATIONS.SOURCE_TELEGRAM' },
  { value: 'whatsapp', labelKey: 'CAPTAIN.MIGRATIONS.SOURCE_WHATSAPP' },
  { value: 'vk', labelKey: 'CAPTAIN.MIGRATIONS.SOURCE_VK' },
];

function statusLabel(status) {
  if (!status) return '';
  const key = `CAPTAIN.MIGRATIONS.STATUS_${status.toUpperCase()}`;
  return key;
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

function submitMigration() {
  createError.value = '';
  if (!form.value.file) {
    createError.value = 'CAPTAIN.MIGRATIONS.ERROR_FILE_REQUIRED';
    return;
  }
  if (!form.value.inboxId) {
    createError.value = 'CAPTAIN.MIGRATIONS.ERROR_INBOX_REQUIRED';
    return;
  }

  isSubmitting.value = true;
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

  BulkMigrationsAPI.create(fd)
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

          <div>
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

          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
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
          <div
            v-else
            class="overflow-x-auto rounded border border-n-slate-8 bg-n-surface-2"
          >
            <table class="w-full min-w-[600px] text-left text-sm">
              <thead class="border-b border-n-slate-8 bg-n-surface-3">
                <tr>
                  <th class="px-4 py-2 font-medium text-n-slate-12">
                    {{ $t('CAPTAIN.MIGRATIONS.TABLE_ID') }}
                  </th>
                  <th class="px-4 py-2 font-medium text-n-slate-12">
                    {{ $t('CAPTAIN.MIGRATIONS.SOURCE') }}
                  </th>
                  <th class="px-4 py-2 font-medium text-n-slate-12">
                    {{ $t('CAPTAIN.MIGRATIONS.STATUS') }}
                  </th>
                  <th class="px-4 py-2 font-medium text-n-slate-12">
                    {{ $t('CAPTAIN.MIGRATIONS.PROGRESS') }}
                  </th>
                  <th class="px-4 py-2 font-medium text-n-slate-12">
                    {{ $t('CAPTAIN.MIGRATIONS.CREATED_AT') }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="m in migrations"
                  :key="m.id"
                  class="border-b border-n-slate-8 last:border-0"
                >
                  <td class="px-4 py-2 text-n-slate-12">{{ m.id }}</td>
                  <td class="px-4 py-2 text-n-slate-12">{{ m.source }}</td>
                  <td class="px-4 py-2 text-n-slate-12">
                    {{ $t(statusLabel(m.status)) }}
                  </td>
                  <td class="px-4 py-2 text-n-slate-12">
                    <span v-if="m.status === 'processing'">
                      {{ m.processed }}
                      {{ $t('CAPTAIN.MIGRATIONS.TABLE_SEPARATOR') }}
                      {{ m.total_dialogs || '…' }}
                      ({{ m.progress_percent ?? 0 }}%)
                    </span>
                    <span v-else>
                      {{ m.processed ?? 0 }}
                      {{ $t('CAPTAIN.MIGRATIONS.TABLE_SEPARATOR') }}
                      {{ m.total_dialogs ?? 0 }}
                    </span>
                  </td>
                  <td class="px-4 py-2 text-n-slate-11">
                    {{
                      m.created_at
                        ? new Date(m.created_at).toLocaleString()
                        : $t('CAPTAIN.MIGRATIONS.TABLE_NA')
                    }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </template>
  </PageLayout>
</template>
