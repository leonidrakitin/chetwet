<script setup>
import { ref, computed, onBeforeUnmount, nextTick, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import { vOnClickOutside } from '@vueuse/components';
import ContactAPI from 'dashboard/api/contacts';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  normalizeContactSearchQuery,
  isPhoneLikeQuery,
  MIN_SEARCH_LENGTH,
} from '../helpers/contactSearchQuery';

const props = defineProps({
  modelValue: { type: Object, default: null },
  placeholder: { type: String, default: '' },
  hasError: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const query = ref('');
const results = ref([]);
const isLoading = ref(false);
const isOpen = ref(false);
const highlightedIndex = ref(-1);
const inputRef = ref(null);
const listRef = ref(null);

let abortController = null;

const hasSelection = computed(() => !!props.modelValue);
const trimmedQuery = computed(() => query.value.trim());
const normalizedQuery = computed(() =>
  normalizeContactSearchQuery(query.value)
);
const queryIsPhoneLike = computed(() => isPhoneLikeQuery(query.value));
const showMinLengthHint = computed(
  () =>
    isOpen.value &&
    trimmedQuery.value.length > 0 &&
    normalizedQuery.value.length < MIN_SEARCH_LENGTH
);
const showDropdown = computed(
  () =>
    isOpen.value &&
    (isLoading.value ||
      results.value.length > 0 ||
      showMinLengthHint.value ||
      (normalizedQuery.value.length >= MIN_SEARCH_LENGTH && !isLoading.value))
);

const subtitle = contact => {
  const parts = [contact.phone_number, contact.email].filter(Boolean);
  return parts.join(' · ');
};

const escapeRegExp = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const escapeHtml = value =>
  value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const highlight = (text, token) => {
  if (!text) return '';
  const safeText = escapeHtml(String(text));
  if (!token) return safeText;
  const safeToken = escapeHtml(token);
  const pattern = new RegExp(`(${escapeRegExp(safeToken)})`, 'ig');
  return safeText.replace(
    pattern,
    '<mark class="bg-n-amber-4 text-n-text-display rounded-sm px-0.5">$1</mark>'
  );
};

const highlightName = contact => highlight(contact.name, trimmedQuery.value);

const highlightSubtitle = contact => {
  const text = subtitle(contact);
  if (!text) return '';
  // For phone-like queries, highlight the normalized digit substring so that
  // searching "89819723429" still highlights "9819723429" inside "+79819723429".
  const token = queryIsPhoneLike.value
    ? normalizedQuery.value
    : trimmedQuery.value;
  return highlight(text, token);
};

const runSearch = async raw => {
  const normalized = normalizeContactSearchQuery(raw);
  if (!normalized || normalized.length < MIN_SEARCH_LENGTH) {
    results.value = [];
    highlightedIndex.value = -1;
    isLoading.value = false;
    return;
  }
  if (abortController) abortController.abort();
  abortController = new AbortController();
  isLoading.value = true;
  try {
    const { data } = await ContactAPI.search(normalized, 1, 'name', '', {
      signal: abortController.signal,
    });
    results.value = (data.payload || []).slice(0, 10);
    highlightedIndex.value = results.value.length ? 0 : -1;
  } catch (err) {
    if (err.name !== 'CanceledError' && err.name !== 'AbortError') {
      results.value = [];
      highlightedIndex.value = -1;
    }
  } finally {
    isLoading.value = false;
  }
};

const debouncedSearch = debounce(runSearch, 300, false);

const onInput = event => {
  query.value = event.target.value;
  isOpen.value = true;
  debouncedSearch(query.value);
};

const onFocus = () => {
  isOpen.value = true;
};

const close = () => {
  isOpen.value = false;
};

const clearQuery = () => {
  query.value = '';
  results.value = [];
  highlightedIndex.value = -1;
  isOpen.value = true;
  nextTick(() => inputRef.value?.focus());
};

const pick = contact => {
  emit('update:modelValue', contact);
  query.value = '';
  results.value = [];
  highlightedIndex.value = -1;
  isOpen.value = false;
};

const clearSelection = () => {
  emit('update:modelValue', null);
  query.value = '';
  isOpen.value = true;
  nextTick(() => inputRef.value?.focus());
};

const onKeydown = event => {
  if (event.key === 'ArrowDown') {
    if (!results.value.length) return;
    event.preventDefault();
    highlightedIndex.value = Math.min(
      highlightedIndex.value + 1,
      results.value.length - 1
    );
    return;
  }
  if (event.key === 'ArrowUp') {
    if (!results.value.length) return;
    event.preventDefault();
    highlightedIndex.value = Math.max(highlightedIndex.value - 1, 0);
    return;
  }
  if (event.key === 'Enter') {
    if (!results.value.length) return;
    event.preventDefault();
    const idx = highlightedIndex.value >= 0 ? highlightedIndex.value : 0;
    pick(results.value[idx]);
    return;
  }
  if (event.key === 'Escape') {
    close();
  }
};

watch(highlightedIndex, index => {
  if (index < 0 || !listRef.value) return;
  const el = listRef.value.querySelector(`[data-idx="${index}"]`);
  el?.scrollIntoView({ block: 'nearest' });
});

onBeforeUnmount(() => {
  if (abortController) abortController.abort();
});
</script>

<template>
  <div v-on-click-outside="close" class="relative">
    <div
      v-if="hasSelection"
      class="group flex items-center gap-3 px-3 py-2.5 border rounded-xl bg-n-alpha-1 shadow-sm transition-colors"
      :class="hasError ? 'border-n-ruby-9' : 'border-n-border-glass-soft'"
    >
      <Avatar
        :name="modelValue.name || '?'"
        :src="modelValue.thumbnail || ''"
        :size="40"
      />
      <div class="flex-1 min-w-0">
        <p class="text-sm font-semibold text-n-text-display truncate">
          {{ modelValue.name || '—' }}
        </p>
        <p
          v-if="subtitle(modelValue)"
          class="text-xs text-n-text-body/60 truncate font-mono mt-0.5"
        >
          {{ subtitle(modelValue) }}
        </p>
      </div>
      <button
        type="button"
        :title="t('SCHEDULE.MODAL.CLEAR_CONTACT')"
        class="flex items-center justify-center size-8 rounded-lg text-n-text-body hover:text-n-text-display hover:bg-n-alpha-2 transition-colors"
        @click="clearSelection"
      >
        <Icon icon="i-lucide-x" class="size-4" />
      </button>
    </div>

    <div v-else class="relative">
      <div
        class="absolute left-0 top-0 flex items-center justify-center w-8 h-full pointer-events-none ltr:left-0 rtl:right-0"
      >
        <Icon
          icon="i-lucide-search"
          class="size-4 text-n-text-body/60 shrink-0"
        />
      </div>
      <input
        ref="inputRef"
        :value="query"
        type="search"
        :placeholder="placeholder"
        autocomplete="off"
        spellcheck="false"
        class="w-full h-8 [&:not(:focus)]:!border-transparent bg-n-alpha-2 dark:bg-n-glass-soft ltr:!pl-8 !py-1 rtl:!pr-8 outline-n-border-glass-soft dark:outline-n-border-glass-soft hover:outline-n-border-glass dark:hover:outline-n-slate-7 disabled:outline-n-border-glass-soft dark:disabled:outline-n-border-glass-soft focus:outline-n-brand dark:focus:outline-n-brand h-11 !px-4 !py-3 block w-full reset-base text-sm !mb-0 outline outline-1 border-none border-0 outline-offset-[-1px] rounded-xl bg-n-glass-soft shadow-[0_1px_2px_rgba(15,23,42,0.04)] file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-n-text-body/60 dark:placeholder:text-n-text-body/60 disabled:cursor-not-allowed disabled:opacity-50 text-n-text-display transition-all duration-200 ease-out [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none"
        @input="onInput"
        @focus="onFocus"
        @keydown="onKeydown"
      />
      <div
        v-if="isLoading"
        class="absolute right-0 top-0 flex items-center justify-center w-8 h-full pointer-events-none"
      >
        <span
          class="i-lucide-loader-2 size-4 text-n-text-body/60 animate-spin shrink-0"
          aria-hidden="true"
        />
      </div>
      <button
        v-else-if="trimmedQuery"
        type="button"
        :title="t('SCHEDULE.MODAL.CLEAR_CONTACT')"
        class="absolute right-0 top-0 flex items-center justify-center w-8 h-full text-n-text-body/60 hover:text-n-text-display hover:bg-n-alpha-2 transition-colors shrink-0"
        @click="clearQuery"
      >
        <Icon icon="i-lucide-x" class="size-3.5" />
      </button>
    </div>

    <div
      v-if="showDropdown"
      class="absolute left-0 right-0 top-full mt-2 z-50 bg-n-glass-soft border border-n-border-glass-soft rounded-xl shadow-xl overflow-hidden"
    >
      <div
        v-if="showMinLengthHint"
        class="px-3 py-3 text-xs text-n-text-body/60 text-center"
      >
        {{ t('SCHEDULE.MODAL.SEARCH_CONTACT_HINT') }}
      </div>
      <div
        v-else-if="isLoading && !results.length"
        class="flex items-center gap-2 justify-center px-3 py-4 text-xs text-n-text-body/60"
      >
        <span class="i-lucide-loader-2 size-3.5 animate-spin" />
        <span>{{ t('SCHEDULE.MODAL.SEARCH_CONTACT_LOADING') }}</span>
      </div>
      <div
        v-else-if="!results.length"
        class="flex flex-col items-center gap-1.5 px-3 py-6 text-xs text-n-text-body/60"
      >
        <span class="i-lucide-user-search size-6 opacity-60" />
        <span class="font-medium text-n-text-body">
          {{ t('SCHEDULE.MODAL.SEARCH_CONTACT_EMPTY') }}
        </span>
        <span class="text-n-text-body/60">
          {{ t('SCHEDULE.MODAL.SEARCH_CONTACT_EMPTY_HINT') }}
        </span>
      </div>
      <template v-else>
        <ul ref="listRef" class="py-1 max-h-72 overflow-y-auto">
          <li v-for="(contact, index) in results" :key="contact.id">
            <button
              type="button"
              :data-idx="index"
              class="flex items-center gap-3 w-full px-3 py-2 text-left transition-colors"
              :class="
                index === highlightedIndex
                  ? 'bg-n-alpha-2'
                  : 'hover:bg-n-alpha-1'
              "
              @mouseenter="highlightedIndex = index"
              @click="pick(contact)"
            >
              <Avatar
                :name="contact.name || '?'"
                :src="contact.thumbnail || ''"
                :size="32"
              />
              <div class="flex-1 min-w-0">
                <p
                  class="text-sm font-medium text-n-text-display truncate"
                  v-html="highlightName(contact)"
                />
                <p
                  v-if="subtitle(contact)"
                  class="text-xs text-n-text-body/60 truncate font-mono mt-0.5"
                  v-html="highlightSubtitle(contact)"
                />
              </div>
              <span
                v-if="index === highlightedIndex"
                class="i-lucide-corner-down-left size-3.5 text-n-text-body/60 shrink-0"
                aria-hidden="true"
              />
            </button>
          </li>
        </ul>
        <div
          class="flex items-center justify-between gap-2 px-3 py-2 border-t border-n-border-glass-soft bg-n-alpha-1 text-[11px] text-n-text-body/60"
        >
          <span>{{
            t('SCHEDULE.MODAL.SEARCH_CONTACT_COUNT', {
              count: results.length,
            })
          }}</span>
          <span class="flex items-center gap-1">
            <span
              class="flex items-center justify-center rounded bg-n-glass-strong border border-n-border-glass-soft size-4"
              :title="t('SCHEDULE.MODAL.SEARCH_CONTACT_KBD_NAV')"
            >
              <Icon icon="i-lucide-arrow-up" class="size-3" />
            </span>
            <span
              class="flex items-center justify-center rounded bg-n-glass-strong border border-n-border-glass-soft size-4"
              :title="t('SCHEDULE.MODAL.SEARCH_CONTACT_KBD_NAV')"
            >
              <Icon icon="i-lucide-arrow-down" class="size-3" />
            </span>
            <span
              class="flex items-center justify-center rounded bg-n-glass-strong border border-n-border-glass-soft size-4 ml-1"
              :title="t('SCHEDULE.MODAL.SEARCH_CONTACT_KBD_PICK')"
            >
              <Icon icon="i-lucide-corner-down-left" class="size-3" />
            </span>
          </span>
        </div>
      </template>
    </div>
  </div>
</template>
