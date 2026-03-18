<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Draggable from 'vuedraggable';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TemplateCard from './components/TemplateCard.vue';
import TemplateModal from './components/TemplateModal.vue';
import NotificationTemplatePreview from './components/NotificationTemplatePreview.vue';
import FlowMap from './components/FlowMap.vue';
import TemplateCategorySection from './components/TemplateCategorySection.vue';
import { BUILTIN_CATEGORIES } from './constants/builtinCategories.js';

const { t } = useI18n();
const store = useStore();

const tabs = computed(() => [
  { label: t('NOTIFICATION_TEMPLATES.TABS.ALL'), key: 'all' },
  { label: t('NOTIFICATION_TEMPLATES.TABS.EVENT'), key: 'event' },
  { label: t('NOTIFICATION_TEMPLATES.TABS.TIME'), key: 'time' },
  { label: t('NOTIFICATION_TEMPLATES.TABS.INTERVAL'), key: 'interval' },
  { label: t('NOTIFICATION_TEMPLATES.TABS.STATISTICS'), key: 'statistics' },
]);

const activeTabIndex = ref(0);
const activeTab = computed(() => tabs.value[activeTabIndex.value]);

const onTabChanged = tab => {
  const index = tabs.value.findIndex(item => item.key === tab.key);
  if (index !== -1) activeTabIndex.value = index;
};

const allTemplates = computed(
  () => store.getters['notificationTemplates/getTemplates']
);
const notificationTemplateMeta = computed(
  () => store.getters['notificationTemplates/getMeta']
);
const inboxes = computed(() => store.getters['inboxes/getInboxes']);
const accountLabels = computed(() => store.getters['labels/getLabels']);

const searchQuery = ref('');
const searchExpanded = ref(false);
const viewMode = ref('categories'); // 'categories' | 'grid' | 'flow'

const viewModes = computed(() => [
  {
    key: 'categories',
    icon: 'i-lucide-layers',
    label: t('NOTIFICATION_TEMPLATES.VIEW.CATEGORIES'),
  },
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
  const key = activeTab.value.key;
  let templates =
    key === 'all' || key === 'statistics'
      ? allTemplates.value
      : store.getters['notificationTemplates/getTemplatesByType'](key);

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

const isStatisticsTab = computed(() => activeTab.value.key === 'statistics');

const templateModalRef = ref(null);
const deleteDialogRef = ref(null);
const previewDialogRef = ref(null);
const editingTemplate = ref(null);
const deletingTemplate = ref(null);
const previewingTemplate = ref(null);

const openNewTemplate = () => {
  editingTemplate.value = null;
  templateModalRef.value?.open();
};

const handleEdit = template => {
  editingTemplate.value = { ...template };
  templateModalRef.value?.open();
};

const handleSave = async formData => {
  try {
    if (formData.id) {
      await store.dispatch('notificationTemplates/update', formData);
    } else {
      await store.dispatch('notificationTemplates/create', formData);
    }
    useAlert(t('NOTIFICATION_TEMPLATES.SAVE.SUCCESS'));
  } catch {
    useAlert(t('NOTIFICATION_TEMPLATES.SAVE.ERROR'));
  }
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
  previewingTemplate.value = template;
  previewDialogRef.value?.open();
};

const handleDeleteRequest = template => {
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

// Categories view
const categorizedTemplates = computed(() => {
  return BUILTIN_CATEGORIES.map(cat => {
    if (cat.key === 'yours') {
      return {
        ...cat,
        templates: filteredTemplates.value.map(tmpl => ({
          ...tmpl,
          icon: 'i-lucide-file-text',
        })),
      };
    }
    return {
      ...cat,
      templates: cat.templates.map(bt => ({
        ...bt,
        name: t(
          `NOTIFICATION_TEMPLATES.CATEGORIES.${cat.key.toUpperCase()}.${bt.builtinKey}.NAME`
        ),
        description: t(
          `NOTIFICATION_TEMPLATES.CATEGORIES.${cat.key.toUpperCase()}.${bt.builtinKey}.DESCRIPTION`
        ),
        enabled: true,
        builtin: true,
      })),
    };
  });
});

const handleToggle = async template => {
  if (template.builtin) return;
  try {
    await store.dispatch('notificationTemplates/update', {
      ...template,
      enabled: !template.enabled,
    });
    useAlert(t('NOTIFICATION_TEMPLATES.TOGGLE.SUCCESS'));
  } catch {
    useAlert(t('NOTIFICATION_TEMPLATES.TOGGLE.ERROR'));
  }
};

onMounted(() => {
  store.dispatch('notificationTemplates/get');
  if (!inboxes.value.length) {
    store.dispatch('inboxes/get');
  }
  if (!accountLabels.value.length) {
    store.dispatch('labels/get');
  }
});
</script>

<template>
  <div class="flex flex-col h-full w-full min-w-0 overflow-hidden">
    <!-- Header -->
    <div
      class="flex flex-col gap-3 px-4 py-4 md:flex-row md:items-center md:justify-between md:px-6 md:py-5 border-b border-n-weak flex-shrink-0"
    >
      <div class="min-w-0">
        <div class="flex items-center gap-2">
          <h1 class="text-lg font-semibold text-n-slate-12 truncate">
            {{ t('NOTIFICATION_TEMPLATES.HEADER') }}
          </h1>
          <span class="text-sm font-normal text-n-slate-9">
            {{ filteredTemplates.length }}
          </span>
        </div>
        <p class="hidden md:block text-sm text-n-slate-10 mt-0.5">
          {{ t('NOTIFICATION_TEMPLATES.DESCRIPTION') }}
        </p>
      </div>

      <!-- Controls row -->
      <div class="flex items-center gap-2 flex-shrink-0">
        <!-- Mobile search expanded -->
        <div
          v-if="searchExpanded"
          class="flex items-center gap-2 flex-1 md:hidden"
        >
          <div class="relative flex-1">
            <span
              class="i-lucide-search absolute left-3 top-1/2 -translate-y-1/2 size-4 text-n-slate-9 pointer-events-none"
            />
            <input
              v-model="searchQuery"
              type="text"
              :placeholder="t('NOTIFICATION_TEMPLATES.SEARCH.PLACEHOLDER')"
              class="h-9 w-full rounded-lg border border-n-weak bg-n-alpha-1 pl-9 pr-3 text-sm text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none transition-colors"
            />
          </div>
          <Button
            variant="ghost"
            color="slate"
            size="sm"
            icon="i-lucide-x"
            @click="
              searchExpanded = false;
              searchQuery = '';
            "
          />
        </div>

        <!-- Normal controls (hidden when mobile search is expanded) -->
        <template v-if="!searchExpanded">
          <!-- Mobile search icon -->
          <Button
            class="md:hidden"
            variant="ghost"
            color="slate"
            size="sm"
            icon="i-lucide-search"
            @click="searchExpanded = true"
          />

          <!-- Desktop search -->
          <div class="relative hidden md:block">
            <span
              class="i-lucide-search absolute left-3 top-1/2 -translate-y-1/2 size-4 text-n-slate-9 pointer-events-none"
            />
            <input
              v-model="searchQuery"
              type="text"
              :placeholder="t('NOTIFICATION_TEMPLATES.SEARCH.PLACEHOLDER')"
              class="h-9 w-48 rounded-lg border border-n-weak bg-n-alpha-1 pl-9 pr-3 text-sm text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none transition-colors"
            />
          </div>

          <!-- New template: desktop with label -->
          <Button
            class="hidden md:inline-flex"
            icon="i-lucide-plus"
            :label="t('NOTIFICATION_TEMPLATES.NEW_TEMPLATE')"
            @click="openNewTemplate"
          />
          <!-- New template: mobile icon only -->
          <Button
            class="inline-flex md:hidden"
            icon="i-lucide-plus"
            @click="openNewTemplate"
          />
        </template>
      </div>
    </div>

    <!-- Tabs + View toggle -->
    <div
      class="px-4 pt-3 md:px-6 md:pt-4 flex-shrink-0 flex items-center justify-between gap-4"
    >
      <div class="overflow-x-auto">
        <TabBar
          :tabs="tabs"
          :initial-active-tab="activeTabIndex"
          @tab-changed="onTabChanged"
        />
      </div>
      <div
        class="flex items-center rounded-lg bg-n-alpha-1 p-0.5 flex-shrink-0"
      >
        <button
          v-for="mode in viewModes"
          :key="mode.key"
          class="flex items-center justify-center size-7 rounded-md transition-colors"
          :class="
            viewMode === mode.key
              ? 'bg-n-solid-active shadow-sm text-n-blue-11'
              : 'text-n-slate-10 hover:text-n-slate-12'
          "
          :title="mode.label"
          @click="viewMode = mode.key"
        >
          <span :class="mode.icon" class="size-4" />
        </button>
      </div>
    </div>

    <!-- Content -->
    <div
      class="flex-1 min-h-0"
      :class="
        viewMode === 'flow'
          ? 'overflow-hidden min-w-0'
          : 'overflow-y-auto px-4 py-3 md:px-6 md:py-4'
      "
    >
      <!-- Statistics tab -->
      <div
        v-if="isStatisticsTab"
        class="flex flex-col items-center justify-center h-full gap-4 py-12"
      >
        <div
          class="flex items-center justify-center size-16 rounded-2xl bg-n-alpha-1"
        >
          <span class="i-lucide-bar-chart-3 size-8 text-n-slate-9" />
        </div>
        <p class="text-sm text-n-slate-10 text-center">
          {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COMING_SOON') }}
        </p>
      </div>

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

      <!-- Categories view -->
      <div
        v-else-if="viewMode === 'categories'"
        class="flex flex-col gap-4 max-w-2xl"
      >
        <TemplateCategorySection
          v-for="cat in categorizedTemplates"
          :key="cat.key"
          :category="cat"
          :templates="cat.templates"
          @toggle="handleToggle"
          @edit="handleEdit"
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
              class="drag-handle absolute top-2 left-2 z-10 opacity-50 md:opacity-0 md:group-hover:opacity-100 transition-opacity cursor-grab p-2 rounded text-n-slate-9 hover:text-n-slate-12"
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

  <TemplateModal
    ref="templateModalRef"
    :template="editingTemplate"
    :all-templates="allTemplates"
    :available-inboxes="inboxes"
    :account-labels="accountLabels"
    :meta="notificationTemplateMeta"
    @save="handleSave"
  />

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
