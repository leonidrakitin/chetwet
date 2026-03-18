<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import SuggestionCard from './components/SuggestionCard.vue';
import CreateSuggestionModal from './components/CreateSuggestionModal.vue';

const { t } = useI18n();
const store = useStore();

const searchQuery = ref('');
const statusFilter = ref('');
const sortBy = ref('votes');
const showCreateModal = ref(false);

const uiFlags = computed(() => store.getters['suggestions/getUIFlags']);
const allSuggestions = computed(
  () => store.getters['suggestions/getSuggestions']
);

const filteredSuggestions = computed(() => {
  let list = [...allSuggestions.value];

  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    list = list.filter(
      s =>
        s.title.toLowerCase().includes(q) ||
        (s.description || '').toLowerCase().includes(q)
    );
  }

  if (statusFilter.value) {
    list = list.filter(s => s.status === statusFilter.value);
  }

  if (sortBy.value === 'latest') {
    list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
  } else {
    list.sort(
      (a, b) =>
        b.upvotes_count -
        b.downvotes_count -
        (a.upvotes_count - a.downvotes_count)
    );
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
  } catch {
    useAlert(t('SUGGESTIONS.DELETE_ERROR'));
  }
};

const onCreated = () => {
  showCreateModal.value = false;
};

onMounted(() => {
  store.dispatch('suggestions/get');
});
</script>

<template>
  <div class="flex flex-col h-full overflow-auto p-6">
    <div class="w-full max-w-3xl mx-auto flex flex-col">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100">
          {{ t('SUGGESTIONS.TITLE') }}
        </h1>
        <button
          class="rounded-xl bg-woot-500 px-4 py-2 text-sm font-medium text-white hover:bg-woot-600"
          @click="showCreateModal = true"
        >
          {{ t('SUGGESTIONS.ADD') }}
        </button>
      </div>

      <div class="flex flex-col gap-3 mb-6">
        <input
          v-model="searchQuery"
          type="text"
          :placeholder="t('SUGGESTIONS.SEARCH_PLACEHOLDER')"
          class="w-full rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm text-slate-700 placeholder-slate-400 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200"
        />
        <div class="flex gap-3">
          <select
            v-model="statusFilter"
            class="flex-1 rounded-xl border border-slate-200 bg-white py-2 pl-4 pr-8 text-sm text-slate-700 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200"
          >
            <option value="">
              {{ t('SUGGESTIONS.FILTER_ALL') }}
            </option>
            <option value="pending">
              {{ t('SUGGESTIONS.STATUS_PENDING') }}
            </option>
            <option value="approved">
              {{ t('SUGGESTIONS.STATUS_APPROVED') }}
            </option>
            <option value="rejected">
              {{ t('SUGGESTIONS.STATUS_REJECTED') }}
            </option>
          </select>
          <select
            v-model="sortBy"
            class="flex-1 rounded-xl border border-slate-200 bg-white py-2 pl-4 pr-8 text-sm text-slate-700 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200"
          >
            <option value="votes">
              {{ t('SUGGESTIONS.SORT_VOTES') }}
            </option>
            <option value="latest">
              {{ t('SUGGESTIONS.SORT_LATEST') }}
            </option>
          </select>
        </div>
      </div>

      <div
        v-if="uiFlags.isFetching"
        class="flex items-center justify-center py-20"
      >
        <span class="text-slate-400">{{ t('SUGGESTIONS.LOADING') }}</span>
      </div>

      <div
        v-else-if="filteredSuggestions.length === 0"
        class="flex flex-col items-center justify-center py-20"
      >
        <span class="text-slate-400 text-sm">
          {{ t('SUGGESTIONS.EMPTY') }}
        </span>
      </div>

      <div v-else class="flex flex-col gap-3">
        <SuggestionCard
          v-for="suggestion in filteredSuggestions"
          :key="suggestion.id"
          :suggestion="suggestion"
          @vote="onVote"
          @delete="onDelete"
        />
      </div>
    </div>

    <CreateSuggestionModal
      v-if="showCreateModal"
      @close="showCreateModal = false"
      @created="onCreated"
    />
  </div>
</template>
