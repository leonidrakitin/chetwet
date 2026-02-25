<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import FilterButton from 'dashboard/components/ui/Dropdown/DropdownButton.vue';
import ListItemButton from 'dashboard/components/ui/Dropdown/DropdownListItemButton.vue';
import DropdownEmptyState from 'dashboard/components/ui/Dropdown/DropdownEmptyState.vue';
import { vOnClickaway } from '@vueuse/components';

const emit = defineEmits(['agentsFilterSelection']);
const { t } = useI18n();
const store = useStore();

const showMenu = ref(false);
const selectedAgents = ref([]);

const options = computed(() => {
  const agents = store.getters['agents/getAgents'] || [];
  return agents.map(a => ({ id: a.id, name: a.name || a.email }));
});

const buttonLabel = computed(() => {
  if (selectedAgents.value.length === 0) {
    return t('AGENT_REPORTS.FILTER_DROPDOWN_LABEL');
  }
  if (selectedAgents.value.length === 1) {
    const a = options.value.find(o => o.id === selectedAgents.value[0].id);
    return a?.name || t('AGENT_REPORTS.FILTER_DROPDOWN_LABEL');
  }
  return (
    t('AGENT_REPORTS.FILTER_DROPDOWN_LABEL') +
    ` (${selectedAgents.value.length})`
  );
});

const isSelected = id => selectedAgents.value.some(a => a.id === id);

const toggle = item => {
  const idx = selectedAgents.value.findIndex(a => a.id === item.id);
  if (idx >= 0) {
    selectedAgents.value = selectedAgents.value.filter((_, i) => i !== idx);
  } else {
    selectedAgents.value = [
      ...selectedAgents.value,
      { id: item.id, name: item.name },
    ];
  }
  emit('agentsFilterSelection', [...selectedAgents.value]);
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
