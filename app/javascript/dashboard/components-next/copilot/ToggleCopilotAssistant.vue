<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import { useAdmin } from 'dashboard/composables/useAdmin';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownContainer from 'next/dropdown-menu/base/DropdownContainer.vue';
import DropdownSection from 'next/dropdown-menu/base/DropdownSection.vue';
import DropdownBody from 'next/dropdown-menu/base/DropdownBody.vue';
import DropdownItem from 'next/dropdown-menu/base/DropdownItem.vue';
import CreateAssistantDialog from 'dashboard/components-next/captain/pageComponents/assistant/CreateAssistantDialog.vue';
import CreateFromTemplateDialog from 'dashboard/components-next/captain/pageComponents/assistant/CreateFromTemplateDialog.vue';
import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';

const props = defineProps({
  assistants: {
    type: Array,
    required: true,
  },
  activeAssistant: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['setAssistant']);

const { t } = useI18n();
const { isAdmin } = useAdmin();

const createDialogRef = ref(null);
const editDialogRef = ref(null);
const deleteDialogRef = ref(null);
const selectedAssistant = ref({});
const assistantToDelete = ref({});

const activeAssistantLabel = computed(() => {
  return props.activeAssistant?.name || t('CAPTAIN.COPILOT.SELECT_ASSISTANT');
});

const openCreateDialog = () => {
  createDialogRef.value.open();
};

const openEditDialog = assistant => {
  selectedAssistant.value = assistant;
  editDialogRef.value.dialogRef.open();
};

const openDeleteDialog = assistant => {
  assistantToDelete.value = assistant;
  deleteDialogRef.value.dialogRef.open();
};
</script>

<template>
  <div>
    <DropdownContainer>
      <template #trigger="{ toggle, isOpen }">
        <Button
          :label="activeAssistantLabel"
          icon="i-woot-captain"
          ghost
          slate
          xs
          :class="{ 'bg-n-alpha-2': isOpen }"
          @click="toggle"
        />
      </template>
      <DropdownBody class="bottom-9 min-w-64 z-50" strong>
        <DropdownSection
          v-if="isAdmin"
          class="border-b border-n-border-glass-soft/40 pb-1.5 mb-0.5"
        >
          <div class="px-2 py-1">
            <Button
              :label="t('CAPTAIN.COPILOT.NEW_ASSISTANT')"
              icon="i-lucide-plus"
              ghost
              slate
              xs
              class="w-full !justify-start"
              @click="openCreateDialog"
            />
          </div>
        </DropdownSection>
        <DropdownSection class="[&>ul]:max-h-80">
          <DropdownItem
            v-for="assistant in assistants"
            :key="assistant.id"
            class="!items-start !gap-1 flex-col cursor-pointer"
            @click="() => emit('setAssistant', assistant)"
          >
            <template #label>
              <div class="flex gap-1 justify-between w-full">
                <div class="items-start flex gap-1 flex-col">
                  <span class="text-n-text-display text-sm">
                    {{ assistant.name }}
                  </span>
                  <span class="line-clamp-2 text-n-text-body text-xs">
                    {{ assistant.description }}
                  </span>
                </div>

                <div class="flex items-center gap-1 flex-shrink-0">
                  <template v-if="isAdmin">
                    <Button
                      v-tooltip="t('CAPTAIN.COPILOT.EDIT_ASSISTANT')"
                      icon="i-lucide-pencil"
                      ghost
                      slate
                      xs
                      class="size-6"
                      @click.stop="openEditDialog(assistant)"
                    />
                    <Button
                      v-tooltip="t('CAPTAIN.COPILOT.DELETE_ASSISTANT')"
                      icon="i-lucide-trash-2"
                      ghost
                      slate
                      xs
                      class="size-6 hover:text-r-red-10"
                      @click.stop="openDeleteDialog(assistant)"
                    />
                  </template>
                  <div
                    v-if="assistant.id === activeAssistant?.id"
                    class="flex items-center justify-center flex-shrink-0 w-4 h-4 rounded-full bg-n-slate-12 dark:bg-n-slate-11"
                  >
                    <i
                      class="i-lucide-check text-white dark:text-n-slate-1 size-3"
                    />
                  </div>
                </div>
              </div>
            </template>
          </DropdownItem>
        </DropdownSection>
      </DropdownBody>
    </DropdownContainer>

    <CreateFromTemplateDialog ref="createDialogRef" />
    <CreateAssistantDialog
      ref="editDialogRef"
      type="edit"
      :selected-assistant="selectedAssistant"
    />
    <DeleteDialog
      ref="deleteDialogRef"
      type="Assistants"
      translation-key="ASSISTANTS"
      :entity="assistantToDelete"
    />
  </div>
</template>
