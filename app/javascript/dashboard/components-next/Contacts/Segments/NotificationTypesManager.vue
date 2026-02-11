<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const store = useStore();
const { t } = useI18n();

const notificationTypes = useMapGetter(
  'segmentNotificationTypes/getNotificationTypes'
);
const uiFlags = useMapGetter('segmentNotificationTypes/getUIFlags');

const isAddingNew = ref(false);
const newTypeName = ref('');
const editingId = ref(null);
const editingName = ref('');
const deleteDialogRef = ref(null);
const typeToDelete = ref(null);

const isFetching = computed(() => uiFlags.value.isFetching);

const startAdding = () => {
  isAddingNew.value = true;
  newTypeName.value = '';
};

const cancelAdding = () => {
  isAddingNew.value = false;
  newTypeName.value = '';
};

const saveNewType = async () => {
  if (!newTypeName.value.trim()) return;
  try {
    await store.dispatch('segmentNotificationTypes/create', {
      segment_notification_type: { name: newTypeName.value.trim() },
    });
    useAlert(t('NOTIFICATION_TYPES.CREATE_SUCCESS'));
    cancelAdding();
  } catch (error) {
    useAlert(t('NOTIFICATION_TYPES.CREATE_ERROR'));
  }
};

const startEditing = type => {
  editingId.value = type.id;
  editingName.value = type.name;
};

const cancelEditing = () => {
  editingId.value = null;
  editingName.value = '';
};

const saveEdit = async () => {
  if (!editingName.value.trim()) return;
  try {
    await store.dispatch('segmentNotificationTypes/update', {
      id: editingId.value,
      segment_notification_type: { name: editingName.value.trim() },
    });
    useAlert(t('NOTIFICATION_TYPES.UPDATE_SUCCESS'));
    cancelEditing();
  } catch (error) {
    useAlert(t('NOTIFICATION_TYPES.UPDATE_ERROR'));
  }
};

const toggleActive = async type => {
  try {
    await store.dispatch('segmentNotificationTypes/update', {
      id: type.id,
      segment_notification_type: { active: !type.active },
    });
  } catch (error) {
    useAlert(t('NOTIFICATION_TYPES.UPDATE_ERROR'));
  }
};

const openDeleteDialog = type => {
  typeToDelete.value = type;
  deleteDialogRef.value?.open?.();
};

const deleteType = async () => {
  if (!typeToDelete.value) return;
  try {
    await store.dispatch(
      'segmentNotificationTypes/delete',
      typeToDelete.value.id
    );
    useAlert(t('NOTIFICATION_TYPES.DELETE_SUCCESS'));
    deleteDialogRef.value?.close?.();
    typeToDelete.value = null;
  } catch (error) {
    useAlert(t('NOTIFICATION_TYPES.DELETE_ERROR'));
  }
};
</script>

<template>
  <section>
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-base font-medium text-n-slate-12">
        {{ t('NOTIFICATION_TYPES.TITLE') }}
      </h2>
      <Button
        v-if="!isAddingNew"
        :label="t('NOTIFICATION_TYPES.ADD')"
        icon="i-lucide-plus"
        color="primary"
        size="xs"
        @click="startAdding"
      />
    </div>

    <!-- Add new form -->
    <div
      v-if="isAddingNew"
      class="flex items-center gap-2 mb-3 p-3 rounded-lg border border-n-weak bg-n-background"
    >
      <Input
        v-model="newTypeName"
        :placeholder="t('NOTIFICATION_TYPES.NAME_PLACEHOLDER')"
        class="flex-1"
        @keyup.enter="saveNewType"
      />
      <Button
        :label="t('NOTIFICATION_TYPES.SAVE')"
        color="primary"
        size="xs"
        :disabled="!newTypeName.trim()"
        @click="saveNewType"
      />
      <Button
        :label="t('NOTIFICATION_TYPES.CANCEL')"
        color="slate"
        size="xs"
        @click="cancelAdding"
      />
    </div>

    <!-- Types list -->
    <div
      v-if="isFetching"
      class="flex items-center justify-center py-6 text-n-slate-11"
    >
      <span class="text-sm">{{ t('NOTIFICATION_TYPES.LOADING') }}</span>
    </div>
    <div
      v-else-if="!notificationTypes.length && !isAddingNew"
      class="flex items-center justify-center py-6"
    >
      <span class="text-sm text-n-slate-11">
        {{ t('NOTIFICATION_TYPES.EMPTY') }}
      </span>
    </div>
    <div v-else class="grid gap-2">
      <div
        v-for="type in notificationTypes"
        :key="type.id"
        class="flex items-center justify-between p-3 rounded-lg border border-n-weak bg-n-background"
      >
        <template v-if="editingId === type.id">
          <Input
            v-model="editingName"
            class="flex-1 mr-2"
            @keyup.enter="saveEdit"
          />
          <div class="flex gap-1">
            <Button
              :label="t('NOTIFICATION_TYPES.SAVE')"
              color="primary"
              size="xs"
              :disabled="!editingName.trim()"
              @click="saveEdit"
            />
            <Button
              :label="t('NOTIFICATION_TYPES.CANCEL')"
              color="slate"
              size="xs"
              @click="cancelEditing"
            />
          </div>
        </template>
        <template v-else>
          <div class="flex items-center gap-2 min-w-0">
            <span
              v-if="type.icon"
              :class="type.icon"
              class="size-4 text-n-slate-11"
            />
            <span class="text-sm text-n-slate-12 truncate">
              {{ type.name }}
            </span>
          </div>
          <div class="flex items-center gap-2 flex-shrink-0">
            <button
              class="relative inline-flex h-5 w-9 items-center rounded-full transition-colors"
              :class="type.active ? 'bg-n-teal-9' : 'bg-n-slate-6'"
              @click="toggleActive(type)"
            >
              <span
                class="inline-block h-3.5 w-3.5 rounded-full bg-white transition-transform"
                :class="type.active ? 'translate-x-4' : 'translate-x-0.5'"
              />
            </button>
            <Button
              icon="i-lucide-pencil"
              color="slate"
              size="xs"
              @click="startEditing(type)"
            />
            <Button
              icon="i-lucide-trash-2"
              color="slate"
              size="xs"
              @click="openDeleteDialog(type)"
            />
          </div>
        </template>
      </div>
    </div>

    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="t('NOTIFICATION_TYPES.DELETE_DIALOG.TITLE')"
      :description="t('NOTIFICATION_TYPES.DELETE_DIALOG.DESCRIPTION')"
      :confirm-button-label="t('NOTIFICATION_TYPES.DELETE_DIALOG.CONFIRM')"
      @confirm="deleteType"
    />
  </section>
</template>
