<script setup>
import { ref, computed, onMounted, nextTick, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  suggestion: {
    type: Object,
    required: true,
  },
  canDelete: {
    type: Boolean,
    default: false,
  },
  canEdit: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['vote', 'delete', 'edit']);

const { t } = useI18n();

const expanded = ref(false);
const descRef = ref(null);
const isClamped = ref(false);

const checkClamped = () => {
  if (!descRef.value) return;
  isClamped.value = descRef.value.scrollHeight > descRef.value.clientHeight + 1;
};

onMounted(async () => {
  await nextTick();
  checkClamped();
});

watch(
  () => props.suggestion.description,
  async () => {
    expanded.value = false;
    await nextTick();
    checkClamped();
  }
);

const toggleExpanded = () => {
  expanded.value = !expanded.value;
  if (!expanded.value) {
    nextTick(checkClamped);
  }
};

const statusClasses = {
  pending: 'text-n-amber-11',
  approved: 'text-n-teal-11',
  rejected: 'text-n-ruby-11',
};

const statusLabel = computed(() => ({
  pending: t('SUGGESTIONS.STATUS_PENDING'),
  approved: t('SUGGESTIONS.STATUS_APPROVED'),
  rejected: t('SUGGESTIONS.STATUS_REJECTED'),
}));

const score = computed(
  () => props.suggestion.upvotes_count - props.suggestion.downvotes_count
);

const scoreClass = computed(() => {
  if (score.value > 0) return 'text-n-teal-11';
  if (score.value < 0) return 'text-n-ruby-11';
  return 'text-n-slate-11';
});

const formatDate = dateStr => {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleDateString();
};

const resolveImageUrl = url => {
  if (!url) return '';
  if (url.startsWith('http')) return url;
  const base = window.chatwootConfig?.hostURL?.replace(/\/$/, '') || '';
  return base ? `${base}${url}` : url;
};

const renderedDescription = computed(() => {
  const raw = props.suggestion.description;
  if (!raw) return '';
  return new MessageFormatter(raw).formattedMessage;
});
</script>

<template>
  <CardLayout layout="row">
    <!-- Vote column -->
    <div class="flex flex-col items-center gap-1 shrink-0 w-10">
      <Button
        variant="ghost"
        size="xs"
        icon="i-lucide-thumbs-up"
        :color="suggestion.current_user_vote === 'upvote' ? 'teal' : 'slate'"
        @click="emit('vote', suggestion.id, 'upvote')"
      />
      <span class="text-xs font-semibold" :class="scoreClass">
        {{ score }}
      </span>
      <Button
        variant="ghost"
        size="xs"
        icon="i-lucide-thumbs-down"
        :color="suggestion.current_user_vote === 'downvote' ? 'ruby' : 'slate'"
        @click="emit('vote', suggestion.id, 'downvote')"
      />
    </div>

    <!-- Content -->
    <div class="flex-1 min-w-0 overflow-hidden">
      <div class="flex items-start justify-between gap-2 mb-1">
        <span class="text-sm font-medium text-n-slate-12 truncate">
          {{ suggestion.title }}
        </span>
        <div class="flex items-center gap-2 shrink-0">
          <span
            v-if="suggestion.status"
            class="text-xs font-medium inline-flex items-center h-5 px-2 rounded-md bg-n-alpha-2"
            :class="statusClasses[suggestion.status]"
          >
            {{ statusLabel[suggestion.status] }}
          </span>
          <Button
            v-if="canEdit"
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-pencil"
            :aria-label="t('SUGGESTIONS.EDIT')"
            @click="emit('edit', suggestion)"
          />
          <Button
            v-if="canDelete"
            variant="ghost"
            color="ruby"
            size="xs"
            icon="i-lucide-trash-2"
            :aria-label="t('SUGGESTIONS.DELETE')"
            @click="emit('delete', suggestion.id)"
          />
        </div>
      </div>

      <div
        v-if="(suggestion.images || []).length"
        class="flex flex-wrap gap-2 mb-2"
      >
        <a
          v-for="img in suggestion.images"
          :key="img.id"
          :href="resolveImageUrl(img.url)"
          target="_blank"
          rel="noopener noreferrer"
          class="block w-16 h-16 rounded-lg overflow-hidden border border-n-container shrink-0"
        >
          <img
            :src="resolveImageUrl(img.url)"
            alt=""
            class="w-full h-full object-cover"
          />
        </a>
      </div>

      <div v-if="suggestion.description" class="mb-2">
        <div
          ref="descRef"
          class="text-sm text-n-slate-11 break-words prose prose-sm dark:prose-invert max-w-none [&_p]:my-1 [&_p:first-child]:mt-0 [&_ul]:my-1 [&_ol]:my-1"
          :class="{ 'line-clamp-2': !expanded }"
        >
          <div v-dompurify-html="renderedDescription" />
        </div>
        <button
          v-if="isClamped || expanded"
          class="text-xs text-woot-500 hover:text-woot-600 mt-0.5"
          @click="toggleExpanded"
        >
          {{ expanded ? t('SUGGESTIONS.COLLAPSE') : t('SUGGESTIONS.EXPAND') }}
        </button>
      </div>

      <div class="flex flex-wrap items-center gap-1.5 mb-2">
        <span
          v-for="tag in suggestion.tags || []"
          :key="tag"
          class="rounded-full bg-n-alpha-2 px-2.5 py-0.5 text-xs font-medium text-n-slate-11"
        >
          {{ tag }}
        </span>
      </div>

      <div class="flex items-center gap-3 text-xs text-n-slate-9">
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
  </CardLayout>
</template>
