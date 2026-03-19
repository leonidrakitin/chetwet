<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
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
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="sticky top-0 z-10 px-6">
      <div class="w-full max-w-5xl mx-auto">
        <div class="flex items-center justify-between w-full h-20 gap-2">
          <span class="text-heading-1 text-n-slate-12">
            {{ t('SUGGESTIONS.TITLE') }}
          </span>
          <Button
            :label="t('SUGGESTIONS.ADD')"
            icon="i-lucide-plus"
            size="sm"
            @click="showCreateModal = true"
          />
        </div>
      </div>
    </header>

    <main class="flex-1 px-6 overflow-y-auto">
      <div class="w-full max-w-5xl mx-auto py-4">
        <div class="flex gap-3 mb-4">
          <input
            v-model="searchQuery"
            type="text"
            :placeholder="t('SUGGESTIONS.SEARCH_PLACEHOLDER')"
            class="flex-1 rounded-xl border border-n-container bg-n-solid-2 px-4 py-2 text-sm text-n-slate-12 placeholder-n-slate-9 outline-none focus:border-woot-500"
          />
          <select
            v-model="statusFilter"
            class="rounded-xl border border-n-container bg-n-solid-2 py-2 pl-4 pr-8 text-sm text-n-slate-12 outline-none focus:border-woot-500"
          >
            <option value="">{{ t('SUGGESTIONS.FILTER_ALL') }}</option>
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
            class="rounded-xl border border-n-container bg-n-solid-2 py-2 pl-4 pr-8 text-sm text-n-slate-12 outline-none focus:border-woot-500"
          >
            <option value="votes">{{ t('SUGGESTIONS.SORT_VOTES') }}</option>
            <option value="latest">{{ t('SUGGESTIONS.SORT_LATEST') }}</option>
          </select>
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
    </main>

    <CreateSuggestionModal
      v-if="showCreateModal"
      @close="showCreateModal = false"
      @created="onCreated"
    />
  </section>
</template>
