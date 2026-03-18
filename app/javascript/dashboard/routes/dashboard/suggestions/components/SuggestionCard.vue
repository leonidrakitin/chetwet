<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  suggestion: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['vote', 'delete']);

const { t } = useI18n();

const expanded = ref(false);

const statusClasses = {
  pending:
    'bg-yellow-50 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400',
  approved:
    'bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-400',
  rejected: 'bg-red-50 text-red-700 dark:bg-red-900/30 dark:text-red-400',
};

const statusLabel = {
  pending: t('SUGGESTIONS.STATUS_PENDING'),
  approved: t('SUGGESTIONS.STATUS_APPROVED'),
  rejected: t('SUGGESTIONS.STATUS_REJECTED'),
};

const score = computed(
  () => props.suggestion.upvotes_count - props.suggestion.downvotes_count
);

const formatDate = dateStr => {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleDateString();
};
</script>

<template>
  <div
    class="flex gap-4 rounded-xl border border-slate-200 bg-white p-4 dark:border-slate-700 dark:bg-slate-800 w-full"
  >
    <!-- Vote buttons -->
    <div class="flex flex-col items-center gap-1 shrink-0 w-12">
      <button
        class="flex h-8 w-8 items-center justify-center rounded-lg transition-colors"
        :class="
          suggestion.current_user_vote === 'upvote'
            ? 'bg-green-100 text-green-600 dark:bg-green-900/40'
            : 'text-slate-400 hover:bg-slate-100 hover:text-green-500 dark:hover:bg-slate-700'
        "
        @click="emit('vote', suggestion.id, 'upvote')"
      >
        <i class="i-lucide-thumbs-up w-4 h-4" />
      </button>
      <span
        class="text-sm font-semibold"
        :class="
          score > 0
            ? 'text-green-600'
            : score < 0
              ? 'text-red-500'
              : 'text-slate-400'
        "
      >
        {{ score }}
      </span>
      <button
        class="flex h-8 w-8 items-center justify-center rounded-lg transition-colors"
        :class="
          suggestion.current_user_vote === 'downvote'
            ? 'bg-red-100 text-red-600 dark:bg-red-900/40'
            : 'text-slate-400 hover:bg-slate-100 hover:text-red-500 dark:hover:bg-slate-700'
        "
        @click="emit('vote', suggestion.id, 'downvote')"
      >
        <i class="i-lucide-thumbs-down w-4 h-4" />
      </button>
    </div>

    <!-- Content -->
    <div class="flex-1 min-w-0 overflow-hidden">
      <div class="flex items-start justify-between gap-2 mb-1">
        <h3
          class="text-sm font-semibold text-slate-900 dark:text-slate-100 truncate"
        >
          {{ suggestion.title }}
        </h3>
        <div class="flex items-center gap-2 shrink-0">
          <span
            v-if="suggestion.status"
            class="rounded-full px-2.5 py-0.5 text-xs font-medium"
            :class="statusClasses[suggestion.status]"
          >
            {{ statusLabel[suggestion.status] }}
          </span>
          <button
            type="button"
            class="flex items-center justify-center rounded-lg p-1 text-slate-400 hover:bg-slate-100 hover:text-red-500 dark:text-slate-500 dark:hover:bg-slate-700 dark:hover:text-red-400"
            :aria-label="t('SUGGESTIONS.DELETE')"
            @click="emit('delete', suggestion.id)"
          >
            <i class="i-lucide-trash-2 size-4" />
          </button>
        </div>
      </div>

      <div v-if="suggestion.description" class="mb-2 overflow-hidden">
        <p
          class="text-sm text-slate-600 dark:text-slate-400 break-words"
          :class="{ 'line-clamp-2': !expanded }"
        >
          {{ suggestion.description }}
        </p>
        <button
          class="text-xs text-woot-500 hover:text-woot-600 mt-0.5"
          @click="expanded = !expanded"
        >
          {{ expanded ? t('SUGGESTIONS.COLLAPSE') : t('SUGGESTIONS.EXPAND') }}
        </button>
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <span
          v-for="tag in suggestion.tags || []"
          :key="tag"
          class="rounded-full bg-woot-50 px-2.5 py-0.5 text-xs font-medium text-woot-600 dark:bg-woot-900/30 dark:text-woot-400"
        >
          {{ tag }}
        </span>
      </div>

      <div
        class="flex items-center gap-3 mt-2 text-xs text-slate-400 dark:text-slate-500"
      >
        <span v-if="suggestion.user">{{ suggestion.user.name }}</span>
        <span v-if="formatDate(suggestion.created_at)">
          {{ formatDate(suggestion.created_at) }}
        </span>
        <span>
          {{
            t('SUGGESTIONS.VOTES_LABEL', {
              up: suggestion.upvotes_count,
              down: suggestion.downvotes_count,
            })
          }}
        </span>
      </div>
    </div>
  </div>
</template>
