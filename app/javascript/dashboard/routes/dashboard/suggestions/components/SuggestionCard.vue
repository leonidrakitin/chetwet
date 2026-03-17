<script setup>
import { useI18n } from 'vue-i18n';

const props = defineProps({
  suggestion: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['vote']);

const { t } = useI18n();

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

const score = props.suggestion.upvotes_count - props.suggestion.downvotes_count;

const formatDate = dateStr => {
  return new Date(dateStr).toLocaleDateString();
};
</script>

<template>
  <div
    class="flex gap-4 rounded-xl border border-slate-200 bg-white p-4 dark:border-slate-700 dark:bg-slate-800"
  >
    <!-- Vote buttons -->
    <div class="flex flex-col items-center gap-1 min-w-[48px]">
      <button
        class="flex h-8 w-8 items-center justify-center rounded-lg transition-colors"
        :class="
          suggestion.current_user_vote === 'upvote'
            ? 'bg-green-100 text-green-600 dark:bg-green-900/40'
            : 'text-slate-400 hover:bg-slate-100 hover:text-green-500 dark:hover:bg-slate-700'
        "
        @click="emit('vote', suggestion.id, 'upvote')"
      >
        <span class="i-lucide-thumbs-up text-base" />
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
        <span class="i-lucide-thumbs-down text-base" />
      </button>
    </div>

    <!-- Content -->
    <div class="flex-1 min-w-0">
      <div class="flex items-start justify-between gap-2 mb-1">
        <h3
          class="text-sm font-semibold text-slate-900 dark:text-slate-100 truncate"
        >
          {{ suggestion.title }}
        </h3>
        <span
          class="shrink-0 rounded-full px-2.5 py-0.5 text-xs font-medium"
          :class="statusClasses[suggestion.status]"
        >
          {{ statusLabel[suggestion.status] }}
        </span>
      </div>

      <p
        v-if="suggestion.description"
        class="text-sm text-slate-600 dark:text-slate-400 mb-2 line-clamp-2"
      >
        {{ suggestion.description }}
      </p>

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
        <span>{{ formatDate(suggestion.created_at) }}</span>
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
