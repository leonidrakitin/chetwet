<script setup>
import {
  ref,
  computed,
  watch,
  nextTick,
  onMounted,
  onBeforeUnmount,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { VARIABLE_KEYS, VARIABLE_COLORS } from '../constants/variables';
import VariableSuggestionDropdown from './VariableSuggestionDropdown.vue';

const props = defineProps({
  modelValue: { type: String, default: '' },
  placeholder: { type: String, default: '' },
});

const emit = defineEmits(['update:modelValue', 'toggleAttachments']);

const { t } = useI18n();

const editorRef = ref(null);
const wrapperRef = ref(null);

// === Suggestion state ===
const showSuggestions = ref(false);
const suggestionSearch = ref('');
const suggestionTop = ref(0);
const suggestionLeft = ref(0);
const selectedIdx = ref(0);

// === Variable helpers ===
const getVariableStyle = key => {
  const c = VARIABLE_COLORS[key] ?? { bg: '#e2e8f0', text: '#334155' };
  return `background-color:${c.bg};color:${c.text};`;
};

const getTitle = key => {
  try {
    return `${t(`NOTIFICATION_TEMPLATES.VARIABLES.${key}_description`)} — ${t('NOTIFICATION_TEMPLATES.VARIABLES.EXAMPLE_PREFIX')} ${t(`NOTIFICATION_TEMPLATES.VARIABLES.${key}_example`)}`;
  } catch {
    return key;
  }
};

const createVariableSpan = key => {
  const span = document.createElement('span');
  span.dataset.type = 'variable';
  span.dataset.var = key;
  span.contentEditable = 'false';
  span.className =
    'inline rounded px-0.5 font-medium align-baseline cursor-default select-none';
  span.setAttribute('style', getVariableStyle(key));
  span.title = getTitle(key);
  span.textContent = `@${key}`;
  return span;
};

// === Model → DOM ===
const escapeHtml = str =>
  str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const modelToHtml = text => {
  if (!text) return '';
  const parts = [];
  const regex = /@(\w+)|\n/g;
  let lastIndex = 0;
  let match = regex.exec(text);
  while (match) {
    if (match.index > lastIndex) {
      parts.push(escapeHtml(text.slice(lastIndex, match.index)));
    }
    if (match[0] === '\n') {
      parts.push('<br>');
    } else {
      const key = match[1];
      const style = getVariableStyle(key);
      const title = escapeHtml(getTitle(key));
      parts.push(
        `<span data-type="variable" data-var="${key}" contenteditable="false" class="inline rounded px-0.5 font-medium align-baseline cursor-default select-none" style="${style}" title="${title}">@${key}</span>`
      );
    }
    lastIndex = match.index + match[0].length;
    match = regex.exec(text);
  }
  if (lastIndex < text.length) {
    parts.push(escapeHtml(text.slice(lastIndex)));
  }
  return parts.join('');
};

// === DOM → Model ===
const serializeFromDom = () => {
  const el = editorRef.value;
  if (!el) return '';
  let s = '';
  const walk = node => {
    if (node.nodeType === Node.TEXT_NODE) {
      s += node.textContent;
      return;
    }
    if (node.nodeType !== Node.ELEMENT_NODE) return;
    if (node.dataset?.type === 'variable' && node.dataset?.var) {
      s += `@${node.dataset.var}`;
      return;
    }
    const tag = node.tagName.toLowerCase();
    if (tag === 'br') {
      s += '\n';
      return;
    }
    if ((tag === 'div' || tag === 'p') && node !== el) {
      if (s.length > 0 && !s.endsWith('\n')) s += '\n';
    }
    node.childNodes.forEach(walk);
  };
  el.childNodes.forEach(walk);
  return s;
};

// === Init from model ===
const initFromModel = val => {
  const el = editorRef.value;
  if (!el) return;
  const current = serializeFromDom();
  if (current === (val ?? '')) return;
  el.innerHTML = modelToHtml(val ?? '');
};

watch(
  () => props.modelValue,
  val => nextTick(() => initFromModel(val)),
  { immediate: true, flush: 'post' }
);

// === @ trigger helpers ===
const filteredKeys = computed(() => {
  const term = suggestionSearch.value.toLowerCase();
  if (!term) return VARIABLE_KEYS;
  return VARIABLE_KEYS.filter(
    k =>
      k.includes(term) ||
      t(`NOTIFICATION_TEMPLATES.VARIABLES.${k}`).toLowerCase().includes(term)
  );
});

const updateSuggestionPosition = () => {
  const sel = window.getSelection();
  if (!sel?.rangeCount || !wrapperRef.value) return;
  const range = sel.getRangeAt(0);
  const caretRect = range.getBoundingClientRect();
  const wrapperRect = wrapperRef.value.getBoundingClientRect();
  suggestionTop.value = caretRect.bottom - wrapperRect.top + 4;
  suggestionLeft.value = Math.max(0, caretRect.left - wrapperRect.left);
};

const checkForAtTrigger = () => {
  const sel = window.getSelection();
  if (!sel?.rangeCount || !editorRef.value) {
    showSuggestions.value = false;
    return;
  }
  const range = sel.getRangeAt(0);
  if (!editorRef.value.contains(range.startContainer)) {
    showSuggestions.value = false;
    return;
  }
  if (range.startContainer.nodeType !== Node.TEXT_NODE) {
    showSuggestions.value = false;
    return;
  }
  const textBefore =
    range.startContainer.textContent?.slice(0, range.startOffset) ?? '';
  const atMatch = /@(\w*)$/.exec(textBefore);
  if (atMatch) {
    suggestionSearch.value = atMatch[1];
    selectedIdx.value = 0;
    updateSuggestionPosition();
    showSuggestions.value = true;
  } else {
    showSuggestions.value = false;
  }
};

// === Variable selection (before onKeydown which references it) ===
const onVariableSelect = key => {
  const sel = window.getSelection();
  if (!sel?.rangeCount) {
    showSuggestions.value = false;
    return;
  }
  const range = sel.getRangeAt(0);
  if (range.startContainer.nodeType === Node.TEXT_NODE) {
    const textNode = range.startContainer;
    const offset = range.startOffset;
    const textBefore = textNode.textContent.slice(0, offset);
    const atMatch = /@(\w*)$/.exec(textBefore);
    if (atMatch) {
      const startOfAt = offset - atMatch[0].length;
      const beforeText = textNode.textContent.slice(0, startOfAt);
      const afterText = textNode.textContent.slice(offset);
      const beforeNode = document.createTextNode(beforeText);
      const varSpan = createVariableSpan(key);
      const afterNode = document.createTextNode(afterText);
      const parent = textNode.parentNode;
      parent.replaceChild(afterNode, textNode);
      parent.insertBefore(varSpan, afterNode);
      parent.insertBefore(beforeNode, varSpan);
      const newRange = document.createRange();
      newRange.setStartAfter(varSpan);
      newRange.collapse(true);
      sel.removeAllRanges();
      sel.addRange(newRange);
    }
  }
  showSuggestions.value = false;
  emit('update:modelValue', serializeFromDom());
};

const onInput = () => {
  checkForAtTrigger();
  emit('update:modelValue', serializeFromDom());
};

const onKeydown = e => {
  if (!showSuggestions.value) return;
  const keys = filteredKeys.value;
  if (e.key === 'ArrowDown') {
    e.preventDefault();
    selectedIdx.value = Math.min(selectedIdx.value + 1, keys.length - 1);
  } else if (e.key === 'ArrowUp') {
    e.preventDefault();
    selectedIdx.value = Math.max(selectedIdx.value - 1, 0);
  } else if (e.key === 'Enter') {
    e.preventDefault();
    if (keys[selectedIdx.value]) onVariableSelect(keys[selectedIdx.value]);
  } else if (e.key === 'Escape') {
    showSuggestions.value = false;
  }
};

// === insertAtCursor (before insertAt which references it) ===
const insertAtCursor = text => {
  const el = editorRef.value;
  if (!el) return;
  el.focus();
  const sel = window.getSelection();
  const range = sel?.rangeCount ? sel.getRangeAt(0) : null;
  if (range && el.contains(range.startContainer)) {
    range.deleteContents();
    const node = document.createTextNode(text);
    range.insertNode(node);
    range.setStartAfter(node);
    range.collapse(true);
    sel.removeAllRanges();
    sel.addRange(range);
  } else {
    const node = document.createTextNode(text);
    el.appendChild(node);
    const newRange = document.createRange();
    newRange.setStartAfter(node);
    newRange.collapse(true);
    sel?.removeAllRanges();
    sel?.addRange(newRange);
  }
  emit('update:modelValue', serializeFromDom());
  if (text === '@') nextTick(checkForAtTrigger);
};

// === Close suggestions on outside click (before onMounted which references it) ===
const onDocMousedown = e => {
  if (showSuggestions.value && !wrapperRef.value?.contains(e.target)) {
    showSuggestions.value = false;
  }
};

onMounted(() => {
  document.addEventListener('mousedown', onDocMousedown);
});

onBeforeUnmount(() => {
  document.removeEventListener('mousedown', onDocMousedown);
});

// === Toolbar ===
const wrapSelection = (before, after = before) => {
  editorRef.value?.focus();
  const sel = window.getSelection();
  if (!sel?.rangeCount) return;
  const range = sel.getRangeAt(0);
  if (!editorRef.value.contains(range.commonAncestorContainer)) return;
  if (range.collapsed) {
    const node = document.createTextNode(before + after);
    range.insertNode(node);
    range.setStart(node, before.length);
    range.collapse(true);
    sel.removeAllRanges();
    sel.addRange(range);
  } else {
    const fragment = range.extractContents();
    const beforeNode = document.createTextNode(before);
    const afterNode = document.createTextNode(after);
    range.insertNode(afterNode);
    range.insertNode(fragment);
    range.insertNode(beforeNode);
    range.setStartAfter(afterNode);
    range.collapse(true);
    sel.removeAllRanges();
    sel.addRange(range);
  }
  emit('update:modelValue', serializeFromDom());
};

const insertLink = () => {
  editorRef.value?.focus();
  const sel = window.getSelection();
  if (!sel?.rangeCount) return;
  const range = sel.getRangeAt(0);
  let selectedText = '';
  if (!range.collapsed) {
    const frag = range.cloneContents();
    const temp = document.createElement('div');
    temp.appendChild(frag);
    const walkFrag = node => {
      if (node.nodeType === Node.TEXT_NODE) {
        selectedText += node.textContent;
        return;
      }
      if (node.dataset?.type === 'variable') {
        selectedText += `@${node.dataset.var}`;
        return;
      }
      node.childNodes.forEach(walkFrag);
    };
    temp.childNodes.forEach(walkFrag);
  }
  // eslint-disable-next-line no-alert
  const url = window.prompt(
    t('NOTIFICATION_TEMPLATES.TOOLBAR.LINK_PROMPT'),
    'https://'
  );
  if (!url) return;
  const text = selectedText.trim() || url;
  range.deleteContents();
  const node = document.createTextNode(`[${text}](${url})`);
  range.insertNode(node);
  range.setStartAfter(node);
  range.collapse(true);
  sel.removeAllRanges();
  sel.addRange(range);
  emit('update:modelValue', serializeFromDom());
};

const execCmd = cmd => {
  editorRef.value?.focus();
  // eslint-disable-next-line no-restricted-syntax
  document.execCommand(cmd, false, null);
  emit('update:modelValue', serializeFromDom());
};

const insertAt = () => insertAtCursor('@');

const focus = () => editorRef.value?.focus();

const onBlur = () => {
  emit('update:modelValue', serializeFromDom());
};

const onPaste = e => {
  e.preventDefault();
  const pasted = e.clipboardData?.getData('text/plain') ?? '';
  if (!pasted) return;
  const sel = window.getSelection();
  const range = sel?.rangeCount ? sel.getRangeAt(0) : null;
  if (range) {
    range.deleteContents();
    const node = document.createTextNode(pasted);
    range.insertNode(node);
    range.setStartAfter(node);
    range.collapse(true);
    sel.removeAllRanges();
    sel.addRange(range);
  }
  emit('update:modelValue', serializeFromDom());
};

defineExpose({ insertAtCursor, focus });
</script>

<template>
  <div
    ref="wrapperRef"
    class="relative flex flex-col min-h-[8rem] rounded-lg border border-n-weak bg-n-alpha-1 focus-within:border-n-brand transition-colors"
  >
    <!-- Toolbar -->
    <div
      class="flex items-center gap-0.5 border-b border-n-weak px-1.5 py-1 flex-wrap"
    >
      <button
        v-tooltip.top="t('NOTIFICATION_TEMPLATES.TOOLBAR.BOLD')"
        type="button"
        class="rounded p-1.5 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
        @mousedown.prevent="wrapSelection('**')"
      >
        <span class="i-lucide-bold size-3.5" />
      </button>
      <button
        v-tooltip.top="t('NOTIFICATION_TEMPLATES.TOOLBAR.ITALIC')"
        type="button"
        class="rounded p-1.5 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
        @mousedown.prevent="wrapSelection('_')"
      >
        <span class="i-lucide-italic size-3.5" />
      </button>
      <button
        v-tooltip.top="t('NOTIFICATION_TEMPLATES.TOOLBAR.STRIKETHROUGH')"
        type="button"
        class="rounded p-1.5 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
        @mousedown.prevent="wrapSelection('~~')"
      >
        <span class="i-lucide-strikethrough size-3.5" />
      </button>
      <button
        v-tooltip.top="t('NOTIFICATION_TEMPLATES.TOOLBAR.CODE')"
        type="button"
        class="rounded p-1.5 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
        @mousedown.prevent="wrapSelection('`')"
      >
        <span class="i-lucide-code size-3.5" />
      </button>
      <button
        v-tooltip.top="t('NOTIFICATION_TEMPLATES.TOOLBAR.LINK')"
        type="button"
        class="rounded p-1.5 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
        @mousedown.prevent="insertLink"
      >
        <span class="i-lucide-link size-3.5" />
      </button>
      <button
        v-tooltip.top="t('NOTIFICATION_TEMPLATES.TOOLBAR.UNORDERED_LIST')"
        type="button"
        class="rounded p-1.5 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
        @mousedown.prevent="wrapSelection('\n- ', '')"
      >
        <span class="i-lucide-list size-3.5" />
      </button>
      <button
        v-tooltip.top="t('NOTIFICATION_TEMPLATES.TOOLBAR.ORDERED_LIST')"
        type="button"
        class="rounded p-1.5 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
        @mousedown.prevent="wrapSelection('\n1. ', '')"
      >
        <span class="i-lucide-list-ordered size-3.5" />
      </button>
      <div class="w-px h-4 bg-n-weak mx-0.5 flex-shrink-0" />
      <button
        v-tooltip.top="t('NOTIFICATION_TEMPLATES.TOOLBAR.UNDO')"
        type="button"
        class="rounded p-1.5 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
        @mousedown.prevent="execCmd('undo')"
      >
        <span class="i-lucide-undo-2 size-3.5" />
      </button>
      <button
        v-tooltip.top="t('NOTIFICATION_TEMPLATES.TOOLBAR.REDO')"
        type="button"
        class="rounded p-1.5 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
        @mousedown.prevent="execCmd('redo')"
      >
        <span class="i-lucide-redo-2 size-3.5" />
      </button>
      <div class="w-px h-4 bg-n-weak mx-0.5 flex-shrink-0" />
      <button
        v-tooltip.top="t('NOTIFICATION_TEMPLATES.TOOLBAR.ATTACHMENTS')"
        type="button"
        class="rounded p-1.5 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
        @mousedown.prevent="$emit('toggleAttachments')"
      >
        <span class="i-lucide-paperclip size-3.5" />
      </button>
      <button
        v-tooltip.top="t('NOTIFICATION_TEMPLATES.TOOLBAR.INSERT_VARIABLE')"
        type="button"
        class="rounded p-1.5 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
        @mousedown.prevent="insertAt"
      >
        <span class="i-lucide-at-sign size-3.5" />
      </button>
    </div>

    <!-- Editor -->
    <div
      ref="editorRef"
      contenteditable="true"
      role="textbox"
      :data-placeholder="placeholder"
      class="min-h-24 w-full px-3 py-2 text-sm text-n-slate-12 focus:outline-none break-words empty:before:content-[attr(data-placeholder)] empty:before:text-n-slate-9"
      @input="onInput"
      @keydown="onKeydown"
      @paste="onPaste"
      @blur="onBlur"
    />

    <!-- Variable suggestion dropdown -->
    <VariableSuggestionDropdown
      v-if="showSuggestions"
      :search-term="suggestionSearch"
      :top="suggestionTop"
      :left="suggestionLeft"
      :selected-idx="selectedIdx"
      @select="onVariableSelect"
    />
  </div>
</template>
