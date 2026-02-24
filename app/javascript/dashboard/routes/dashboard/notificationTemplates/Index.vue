<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TemplateCard from './components/TemplateCard.vue';
import TemplateModal from './components/TemplateModal.vue';
import NotificationTemplatePreview from './components/NotificationTemplatePreview.vue';

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

const filteredTemplates = computed(() => {
  const key = activeTab.value.key;
  if (key === 'all' || key === 'statistics') return allTemplates.value;
  return store.getters['notificationTemplates/getTemplatesByType'](key);
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

onMounted(() => {
  store.dispatch('notificationTemplates/get');
});
</script>

<template>
  <div class="flex flex-col h-full overflow-hidden">
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
      <Button
        icon="i-lucide-plus"
        :label="t('NOTIFICATION_TEMPLATES.NEW_TEMPLATE')"
        @click="openNewTemplate"
      />
    </div>

    <div class="px-6 pt-4 flex-shrink-0">
      <TabBar
        :tabs="tabs"
        :initial-active-tab="activeTabIndex"
        @tab-changed="onTabChanged"
      />
    </div>

    <div class="flex-1 overflow-y-auto px-6 py-4">
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

      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <TemplateCard
          v-for="template in filteredTemplates"
          :key="template.id"
          :template="template"
          @toggle="handleToggle"
          @edit="handleEdit"
          @clone="handleClone"
          @delete="handleDeleteRequest"
          @preview="handlePreview"
        />
      </div>
    </div>
  </div>

  <TemplateModal
    ref="templateModalRef"
    :template="editingTemplate"
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
