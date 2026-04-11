<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Draggable from 'vuedraggable';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TemplateCard from './components/TemplateCard.vue';
import NotificationTemplatePreview from './components/NotificationTemplatePreview.vue';
import FlowMap from './components/FlowMap.vue';
import CascadeSettings from './components/CascadeSettings.vue';
import StatisticsTab from './components/StatisticsTab.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const ROUTE_TYPE_MAP = {
  notification_templates_event: 'event',
  notification_templates_time: 'time',
  notification_templates_interval: 'interval',
  notification_templates_delivery: 'cascade',
  notification_templates_statistics: 'statistics',
};

const activeType = computed(() => ROUTE_TYPE_MAP[route.name] || 'all');
const isStatisticsTab = computed(() => activeType.value === 'statistics');
const isCascadeTab = computed(() => activeType.value === 'cascade');
const isTemplateList = computed(
  () => !isStatisticsTab.value && !isCascadeTab.value
);

const uiFlags = computed(
  () => store.getters['notificationTemplates/getUIFlags']
);
const allTemplates = computed(
  () => store.getters['notificationTemplates/getTemplates']
);
const inboxes = computed(() => store.getters['inboxes/getInboxes']);
const accountLabels = computed(() => store.getters['labels/getLabels']);

const searchQuery = ref('');
const inboxFilter = ref('');
const viewMode = ref('grid');

const viewModes = computed(() => [
  {
    key: 'grid',
    icon: 'i-lucide-layout-grid',
    label: t('NOTIFICATION_TEMPLATES.VIEW.GRID'),
  },
  {
    key: 'flow',
    icon: 'i-lucide-git-fork',
    label: t('NOTIFICATION_TEMPLATES.VIEW.FLOW'),
  },
]);

const filteredTemplates = computed(() => {
  const type = activeType.value;
  let templates =
    type === 'all'
      ? allTemplates.value
      : store.getters['notificationTemplates/getTemplatesByType'](type);

  if (inboxFilter.value) {
    templates = templates.filter(tmpl => tmpl.inbox_id === inboxFilter.value);
  }

  const q = searchQuery.value.trim().toLowerCase();
  if (q) {
    templates = templates.filter(
      tmpl =>
        tmpl.name.toLowerCase().includes(q) ||
        (tmpl.messageText ?? '').toLowerCase().includes(q)
    );
  }
  return templates;
});

const deleteDialogRef = ref(null);
const previewDialogRef = ref(null);
const deletingTemplate = ref(null);
const previewingTemplate = ref(null);

const closeAllDialogs = () => {
  deleteDialogRef.value?.close();
  previewDialogRef.value?.close();
};

const openNewTemplate = () => {
  router.push({
    name: 'notification_templates_new',
    params: { accountId: route.params.accountId },
  });
};

const handleEdit = template => {
  router.push({
    name: 'notification_templates_edit',
    params: { accountId: route.params.accountId, templateId: template.id },
  });
};

const handleClone = async id => {
  try {
    await store.dispatch('notificationTemplates/clone', id);
    useAlert(t('NOTIFICATION_TEMPLATES.CLONE.SUCCESS'));
  } catch {
    useAlert(t('NOTIFICATION_TEMPLATES.CLONE.ERROR'));
  }
};

const handlePreview = template => {
  closeAllDialogs();
  previewingTemplate.value = template;
  previewDialogRef.value?.open();
};

const handleDeleteRequest = template => {
  closeAllDialogs();
  deletingTemplate.value = template;
  deleteDialogRef.value?.open();
};

const confirmDelete = async () => {
  if (!deletingTemplate.value) return;
  try {
    await store.dispatch(
      'notificationTemplates/delete',
      deletingTemplate.value.id
    );
    useAlert(t('NOTIFICATION_TEMPLATES.DELETE.SUCCESS'));
  } catch {
    useAlert(t('NOTIFICATION_TEMPLATES.DELETE.ERROR'));
  } finally {
    deletingTemplate.value = null;
    deleteDialogRef.value?.close();
  }
};

// DnD reorder
const orderedTemplates = computed({
  get: () => filteredTemplates.value,
  set: newOrder => {
    store.dispatch('notificationTemplates/reorder', newOrder);
  },
});

watch(
  () => activeType.value,
  type => {
    if (type === 'statistics') {
      store.dispatch('notificationTemplates/fetchStatistics');
    }
  }
);

onMounted(() => {
  store.dispatch('notificationTemplates/get');
  if (!inboxes.value.length) {
    store.dispatch('inboxes/get');
  }
  if (!accountLabels.value.length) {
    store.dispatch('labels/get');
  }
  store.dispatch('notificationTemplates/fetchStatistics');
});
</script>

<template>
  <div
    class="flex flex-col h-full w-full min-w-0 overflow-hidden bg-n-surface-1"
  >
    <!-- Header -->
    <div
      class="sticky top-0 z-10 px-4 md:px-6 bg-n-surface-1 border-b border-n-weak flex-shrink-0"
    >
      <div
        class="flex items-start sm:items-center justify-between w-full py-4 md:py-5 gap-4"
      >
        <div class="flex items-center gap-2 min-w-0">
          <h1 class="text-lg font-semibold text-n-slate-12 truncate">
            {{ t('NOTIFICATION_TEMPLATES.HEADER') }}
          </h1>
          <span
            v-if="isTemplateList"
            class="text-sm font-normal text-n-slate-9"
          >
            {{ filteredTemplates.length }}
          </span>
        </div>

        <!-- Controls row -->
        <div
          class="flex items-center flex-col sm:flex-row flex-shrink-0 gap-3 w-full sm:w-auto"
        >
          <div
            v-if="isTemplateList"
            class="flex items-center gap-2 w-full sm:w-auto"
          >
            <Input
              :model-value="searchQuery"
              type="search"
              :placeholder="t('NOTIFICATION_TEMPLATES.SEARCH.PLACEHOLDER')"
              :custom-input-class="[
                'h-8 [&:not(.focus)]:!border-transparent bg-n-alpha-2 dark:bg-n-solid-1 ltr:!pl-8 !py-1 rtl:!pr-8',
              ]"
              class="w-full sm:w-48"
              @input="searchQuery = $event.target.value"
            >
              <template #prefix>
                <Icon
                  icon="i-lucide-search"
                  class="absolute -translate-y-1/2 text-n-slate-11 size-4 top-1/2 ltr:left-2 rtl:right-2"
                />
              </template>
            </Input>

            <select
              v-model="inboxFilter"
              class="h-8 w-full sm:w-40 rounded-lg border border-n-weak bg-n-alpha-1 pl-3 pr-8 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            >
              <option value="">
                {{ t('NOTIFICATION_TEMPLATES.FORM.INBOX.PLACEHOLDER') }}
              </option>
              <option
                v-for="inbox in inboxes"
                :key="inbox.id"
                :value="inbox.id"
              >
                {{ inbox.name }}
              </option>
            </select>
          </div>

          <div
            v-if="isTemplateList"
            class="flex items-center flex-shrink-0 gap-2 sm:gap-4"
          >
            <!-- View toggles -->
            <div
              class="hidden sm:flex items-center gap-1 rounded-lg bg-n-alpha-1 p-1 flex-shrink-0"
            >
              <button
                v-for="mode in viewModes"
                :key="mode.key"
                class="flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium transition-colors"
                :class="
                  viewMode === mode.key
                    ? 'bg-n-solid-active shadow-sm text-n-blue-11'
                    : 'text-n-slate-10 hover:text-n-slate-12'
                "
                @click="viewMode = mode.key"
              >
                <span :class="mode.icon" class="size-3.5" />
                <span class="hidden md:inline">{{ mode.label }}</span>
              </button>
            </div>

            <div class="hidden sm:block w-px h-4 bg-n-strong shrink-0" />

            <Button
              :label="t('NOTIFICATION_TEMPLATES.NEW_TEMPLATE')"
              icon="i-lucide-plus"
              size="sm"
              @click="openNewTemplate"
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Content -->
    <div
      class="flex-1 min-h-0"
      :class="
        viewMode === 'flow' && isTemplateList
          ? 'overflow-hidden min-w-0'
          : 'overflow-y-auto px-4 py-3 md:px-6 md:py-4'
      "
    >
      <!-- Cascade/Delivery tab -->
      <CascadeSettings v-if="isCascadeTab" />

      <!-- Loading -->
      <div
        v-else-if="uiFlags.isFetching"
        class="flex justify-center items-center py-10 text-n-slate-11"
      >
        <Spinner />
      </div>

      <!-- Statistics tab -->
      <StatisticsTab v-else-if="isStatisticsTab" />

      <!-- Empty state -->
      <div
        v-else-if="filteredTemplates.length === 0"
        class="flex flex-col items-center justify-center h-full gap-4 py-12"
      >
        <div
          class="flex items-center justify-center size-16 rounded-2xl bg-n-alpha-1"
        >
          <span class="i-lucide-mail-plus size-8 text-n-slate-9" />
        </div>
        <div class="flex flex-col items-center gap-1 text-center">
          <p class="text-base font-medium text-n-slate-12">
            {{
              searchQuery
                ? t('NOTIFICATION_TEMPLATES.EMPTY_SEARCH_TITLE')
                : t('NOTIFICATION_TEMPLATES.EMPTY_TITLE')
            }}
          </p>
          <p class="text-sm text-n-slate-10 max-w-sm">
            {{
              searchQuery
                ? t('NOTIFICATION_TEMPLATES.EMPTY_SEARCH_DESCRIPTION')
                : t('NOTIFICATION_TEMPLATES.EMPTY_DESCRIPTION')
            }}
          </p>
        </div>
        <Button
          v-if="!searchQuery"
          variant="outline"
          icon="i-lucide-plus"
          :label="t('NOTIFICATION_TEMPLATES.NEW_TEMPLATE')"
          @click="openNewTemplate"
        />
      </div>

      <!-- Grid view with DnD -->
      <Draggable
        v-else-if="viewMode === 'grid'"
        v-model="orderedTemplates"
        item-key="id"
        handle=".drag-handle"
        ghost-class="opacity-40"
        animation="200"
        class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4"
      >
        <template #item="{ element }">
          <div class="relative group">
            <!-- Drag handle -->
            <div
              class="drag-handle absolute top-[14px] left-1 bottom-auto w-6 h-6 z-10 opacity-50 md:opacity-0 md:group-hover:opacity-100 transition-opacity cursor-grab flex items-center justify-center rounded text-n-slate-9 hover:text-n-slate-12"
            >
              <span class="i-lucide-grip-vertical size-4" />
            </div>
            <TemplateCard
              :template="element"
              @edit="handleEdit"
              @clone="handleClone"
              @delete="handleDeleteRequest"
              @preview="handlePreview"
            />
          </div>
        </template>
      </Draggable>

      <!-- Flow view -->
      <FlowMap
        v-else-if="viewMode === 'flow'"
        :templates="filteredTemplates"
        class="h-full"
        @edit="handleEdit"
      />
    </div>
  </div>

  <Dialog
    ref="previewDialogRef"
    type="edit"
    :title="
      previewingTemplate
        ? previewingTemplate.name
        : t('NOTIFICATION_TEMPLATES.PREVIEW.TITLE')
    "
    :show-confirm-button="false"
    width="sm"
    @close="previewingTemplate = null"
  >
    <NotificationTemplatePreview
      v-if="previewingTemplate"
      :messages="previewingTemplate.messages ?? []"
    />
  </Dialog>

  <Dialog
    ref="deleteDialogRef"
    type="alert"
    :title="t('NOTIFICATION_TEMPLATES.DELETE.CONFIRM.TITLE')"
    :description="
      deletingTemplate
        ? t('NOTIFICATION_TEMPLATES.DELETE.CONFIRM.MESSAGE', {
            name: deletingTemplate.name,
          })
        : ''
    "
    :confirm-button-label="t('NOTIFICATION_TEMPLATES.DELETE.CONFIRM.YES')"
    :cancel-button-label="t('NOTIFICATION_TEMPLATES.DELETE.CONFIRM.NO')"
    @confirm="confirmDelete"
  />
</template>
