<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import FilterButton from 'dashboard/components/ui/Dropdown/DropdownButton.vue';
import ListItemButton from 'dashboard/components/ui/Dropdown/DropdownListItemButton.vue';
import DropdownEmptyState from 'dashboard/components/ui/Dropdown/DropdownEmptyState.vue';

const emit = defineEmits(['inboxFilterSelection']);
const { t } = useI18n();
const store = useStore();

const showMenu = ref(false);
const selectedInboxes = ref([]);

const options = computed(() => {
  const inboxes = store.getters['inboxes/getInboxes'] || [];
  return inboxes.map(inbox => ({ id: inbox.id, name: inbox.name }));
});

const buttonLabel = computed(() => {
  if (selectedInboxes.value.length === 0) {
    return t('INBOX_REPORTS.FILTER_DROPDOWN_LABEL');
  }
  if (selectedInboxes.value.length === 1) {
    const inv = options.value.find(o => o.id === selectedInboxes.value[0].id);
    return inv?.name || t('INBOX_REPORTS.FILTER_DROPDOWN_LABEL');
  }
  return (
    t('INBOX_REPORTS.FILTER_DROPDOWN_LABEL') +
    ` (${selectedInboxes.value.length})`
  );
});

const isSelected = id => selectedInboxes.value.some(inv => inv.id === id);

const toggle = item => {
  const idx = selectedInboxes.value.findIndex(inv => inv.id === item.id);
  if (idx >= 0) {
    selectedInboxes.value = selectedInboxes.value.filter((_, i) => i !== idx);
  } else {
    selectedInboxes.value = [
      ...selectedInboxes.value,
      { id: item.id, name: item.name },
    ];
  }
  emit('inboxFilterSelection', [...selectedInboxes.value]);
};

const toggleDropdown = () => {
  showMenu.value = !showMenu.value;
};

const closeDropdown = () => {
  showMenu.value = false;
};
</script>

<template>
  <FilterButton
    trailing-icon
    icon="i-lucide-chevron-down"
    :button-text="buttonLabel"
    @click="toggleDropdown"
  >
    <template v-if="showMenu" #dropdown>
      <div
        v-on-clickaway="closeDropdown"
        class="absolute z-20 w-40 bg-n-solid-2 border-0 outline outline-1 outline-n-weak shadow rounded-xl max-h-[400px] flex flex-col w-[240px] overflow-y-auto left-0 md:left-auto md:right-0 top-10"
        @click.stop
      >
        <DropdownEmptyState
          v-if="!options.length"
          :message="$t('REPORT.FILTER_ACTIONS.EMPTY_LIST')"
        />
        <ListItemButton
          v-for="item in options"
          :key="item.id"
          :is-active="isSelected(item.id)"
          :button-text="item.name"
          @click.stop.prevent="toggle(item)"
        />
      </div>
    </template>
  </FilterButton>
</template>
