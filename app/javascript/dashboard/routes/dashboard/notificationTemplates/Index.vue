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

const { t } = useI18n();
const store = useStore();

const tabs = computed(() => [
  { label: t('NOTIFICATION_TEMPLATES.TABS.ALL'), key: 'all' },
  { label: t('NOTIFICATION_TEMPLATES.TABS.EVENT'), key: 'event' },
  { label: t('NOTIFICATION_TEMPLATES.TABS.TIME'), key: 'time' },
  { label: t('NOTIFICATION_TEMPLATES.TABS.LOST_CLIENTS'), key: 'lost_clients' },
  {
    label: t('NOTIFICATION_TEMPLATES.TABS.CLIENT_CONSENT'),
    key: 'client_consent',
  },
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

const searchQuery = ref('');
const viewMode = ref('grid'); // 'grid' | 'flow'

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

const handleToggle = async id => {
  try {
    await store.dispatch('notificationTemplates/toggle', id);
    useAlert(t('NOTIFICATION_TEMPLATES.TOGGLE.SUCCESS'));
  } catch {
    useAlert(t('NOTIFICATION_TEMPLATES.TOGGLE.ERROR'));
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

onMounted(() => {
  store.dispatch('notificationTemplates/get');
});
</script>

<template>
  <div class="flex flex-col h-full overflow-hidden">
    <!-- Header -->
    <div
      class="flex items-center justify-between px-6 py-5 border-b border-n-weak flex-shrink-0"
    >
      <div>
        <h1 class="text-lg font-semibold text-n-slate-12">
          {{ t('NOTIFICATION_TEMPLATES.HEADER') }}
        </h1>
        <p class="text-sm text-n-slate-10 mt-0.5">
          {{ t('NOTIFICATION_TEMPLATES.DESCRIPTION') }}
        </p>
      </div>
      <div class="flex items-center gap-2 flex-shrink-0">
        <!-- Search -->
        <div class="relative">
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

        <!-- View mode toggle -->
        <div class="flex rounded-lg border border-n-weak overflow-hidden">
          <button
            class="flex items-center gap-1.5 px-3 py-2 text-sm transition-colors"
            :class="
              viewMode === 'grid'
                ? 'bg-n-brand text-white'
                : 'text-n-slate-10 hover:bg-n-alpha-1'
            "
            @click="viewMode = 'grid'"
          >
            <span class="i-lucide-layout-grid size-4" />
            {{ t('NOTIFICATION_TEMPLATES.VIEW.GRID') }}
          </button>
          <button
            class="flex items-center gap-1.5 px-3 py-2 text-sm transition-colors"
            :class="
              viewMode === 'flow'
                ? 'bg-n-brand text-white'
                : 'text-n-slate-10 hover:bg-n-alpha-1'
            "
            @click="viewMode = 'flow'"
          >
            <span class="i-lucide-git-fork size-4" />
            {{ t('NOTIFICATION_TEMPLATES.VIEW.FLOW') }}
          </button>
        </div>

        <Button
          icon="i-lucide-plus"
          :label="t('NOTIFICATION_TEMPLATES.NEW_TEMPLATE')"
          @click="openNewTemplate"
        />
      </div>
    </div>

    <!-- Tabs -->
    <div class="px-6 pt-4 flex-shrink-0">
      <TabBar
        :tabs="tabs"
        :initial-active-tab="activeTabIndex"
        @tab-changed="onTabChanged"
      />
    </div>

    <!-- Content -->
    <div
      class="flex-1 min-h-0"
      :class="
        viewMode === 'flow' ? 'overflow-hidden' : 'overflow-y-auto px-6 py-4'
      "
    >
      <div
        v-if="isStatisticsTab"
        class="flex items-center justify-center h-full"
      >
        <p class="text-sm text-n-slate-10">
          {{ t('NOTIFICATION_TEMPLATES.STATISTICS.COMING_SOON') }}
        </p>
      </div>

      <div
        v-else-if="filteredTemplates.length === 0"
        class="flex items-center justify-center h-full"
      >
        <p class="text-sm text-n-slate-10">
          {{ t('NOTIFICATION_TEMPLATES.EMPTY') }}
        </p>
      </div>

      <!-- Grid view with DnD -->
      <Draggable
        v-else-if="viewMode === 'grid'"
        v-model="orderedTemplates"
        item-key="id"
        handle=".drag-handle"
        ghost-class="opacity-40"
        animation="200"
        class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"
      >
        <template #item="{ element }">
          <div class="relative group">
            <!-- Drag handle -->
            <div
              class="drag-handle absolute top-2 left-2 z-10 opacity-0 group-hover:opacity-100 transition-opacity cursor-grab p-1 rounded text-n-slate-9 hover:text-n-slate-12"
            >
              <span class="i-lucide-grip-vertical size-4" />
            </div>
            <TemplateCard
              :template="element"
              @toggle="handleToggle"
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
      :message-text="previewingTemplate.messageText"
      :attachments="previewingTemplate.attachments ?? []"
      :buttons="previewingTemplate.buttons ?? []"
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
