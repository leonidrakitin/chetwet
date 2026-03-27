<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import SuggestionCard from './components/SuggestionCard.vue';
import SuggestionFilterMenu from './components/SuggestionFilterMenu.vue';
import SuggestionSortMenu from './components/SuggestionSortMenu.vue';
import SuggestionFormModal from './components/SuggestionFormModal.vue';

const { t } = useI18n();
const store = useStore();
const currentUser = useMapGetter('getCurrentUser');

const searchQuery = ref('');
const statusFilter = ref('');
const sortBy = ref('votes');
const showFormModal = ref(false);
const editingSuggestion = ref(null);
const listScope = ref('all');

const currentUserId = computed(() => currentUser.value?.id);

const uiFlags = computed(() => store.getters['suggestions/getUIFlags']);
const allSuggestions = computed(
  () => store.getters['suggestions/getSuggestions']
);

const filteredSuggestions = computed(() => {
  let list = [...allSuggestions.value];

  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    list = list.filter(s => {
      const plain = (s.description_plain || '').toLowerCase();
      return (s.title || '').toLowerCase().includes(q) || plain.includes(q);
    });
  }

  if (statusFilter.value) {
    list = list.filter(s => s.status === statusFilter.value);
  }

  if (sortBy.value === 'latest') {
    list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
  }

  return list;
});

const onVote = async (id, voteType) => {
  try {
    await store.dispatch('suggestions/vote', { id, voteType });
  } catch {
    useAlert(t('SUGGESTIONS.VOTE_ERROR'));
  }
};

const onDelete = async id => {
  try {
    await store.dispatch('suggestions/delete', id);
    useAlert(t('SUGGESTIONS.DELETE_SUCCESS'));
  } catch (error) {
    const status = error?.response?.status;
    if (status === 403) {
      useAlert(t('SUGGESTIONS.DELETE_FORBIDDEN'));
    } else {
      useAlert(t('SUGGESTIONS.DELETE_ERROR'));
    }
  }
};

const openCreateModal = () => {
  editingSuggestion.value = null;
  showFormModal.value = true;
};

const openEditModal = suggestion => {
  editingSuggestion.value = suggestion;
  showFormModal.value = true;
};

const onFormClose = () => {
  showFormModal.value = false;
  editingSuggestion.value = null;
};

const onFormSaved = () => {
  showFormModal.value = false;
  editingSuggestion.value = null;
};

const fetchSuggestions = () => {
  store.dispatch(
    'suggestions/get',
    listScope.value === 'mine' ? { scope: 'mine' } : {}
  );
};

watch(listScope, fetchSuggestions);

onMounted(() => {
  fetchSuggestions();
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="sticky top-0 z-10 px-6">
      <div
        class="flex items-start sm:items-center justify-between w-full py-6 gap-2 max-w-5xl mx-auto"
      >
        <span class="text-heading-1 text-n-slate-12 truncate">
          {{ t('SUGGESTIONS.TITLE') }}
        </span>
        <div
          class="flex items-center flex-col sm:flex-row flex-shrink-0 gap-4 w-full sm:w-auto"
        >
          <div
            class="flex items-center gap-2 w-full sm:min-w-[12rem] sm:max-w-md"
          >
            <Input
              v-model="searchQuery"
              type="search"
              :placeholder="t('SUGGESTIONS.SEARCH_PLACEHOLDER')"
              :custom-input-class="[
                'h-8 [&:not(.focus)]:!border-transparent bg-n-alpha-2 dark:bg-n-solid-1 ltr:!pl-8 !py-1 rtl:!pr-8',
              ]"
              class="w-full"
            >
              <template #prefix>
                <Icon
                  icon="i-lucide-search"
                  class="absolute -translate-y-1/2 text-n-slate-11 size-4 top-1/2 ltr:left-2 rtl:right-2"
                />
              </template>
            </Input>
          </div>
          <div class="flex items-center flex-shrink-0 gap-2 sm:gap-4">
            <SuggestionFilterMenu v-model="statusFilter" />
            <SuggestionSortMenu v-model="sortBy" />
            <div class="hidden sm:block w-px h-4 bg-n-strong shrink-0" />
            <Button
              :label="t('SUGGESTIONS.ADD')"
              icon="i-lucide-plus"
              size="sm"
              @click="openCreateModal"
            />
          </div>
        </div>
      </div>
    </header>

    <main class="flex-1 px-6 overflow-y-auto">
      <div class="w-full max-w-5xl mx-auto py-4">
        <div
          class="flex w-fit gap-0.5 p-0.5 mb-4 rounded-lg bg-n-alpha-1 dark:bg-n-solid-1"
        >
          <button
            type="button"
            class="px-4 py-1.5 text-sm font-medium rounded-md transition-colors duration-200"
            :class="
              listScope === 'all'
                ? 'bg-n-solid-active text-n-blue-11 shadow-sm outline outline-1 outline-n-container'
                : 'text-n-slate-10 hover:text-n-slate-12'
            "
            @click="listScope = 'all'"
          >
            {{ t('SUGGESTIONS.TAB_ALL') }}
          </button>
          <button
            type="button"
            class="px-4 py-1.5 text-sm font-medium rounded-md transition-colors duration-200"
            :class="
              listScope === 'mine'
                ? 'bg-n-solid-active text-n-blue-11 shadow-sm outline outline-1 outline-n-container'
                : 'text-n-slate-10 hover:text-n-slate-12'
            "
            @click="listScope = 'mine'"
          >
            {{ t('SUGGESTIONS.TAB_MINE') }}
          </button>
        </div>

        <div
          v-if="uiFlags.isFetching"
          class="flex justify-center items-center py-10 text-n-slate-11"
        >
          <Spinner />
        </div>

        <div
          v-else-if="filteredSuggestions.length === 0"
          class="flex flex-col items-center justify-center py-20"
        >
          <span class="text-sm text-n-slate-11">
            {{
              listScope === 'mine'
                ? t('SUGGESTIONS.EMPTY_MINE')
                : t('SUGGESTIONS.EMPTY')
            }}
          </span>
        </div>

        <div v-else class="flex flex-col gap-3">
          <SuggestionCard
            v-for="suggestion in filteredSuggestions"
            :key="suggestion.id"
            :suggestion="suggestion"
            :can-delete="suggestion.user?.id === currentUserId"
            :can-edit="suggestion.user?.id === currentUserId"
            @vote="onVote"
            @delete="onDelete"
            @edit="openEditModal"
          />
        </div>
      </div>
    </main>

    <SuggestionFormModal
      v-if="showFormModal"
      :suggestion="editingSuggestion"
      @close="onFormClose"
      @saved="onFormSaved"
    />
  </section>
</template>
