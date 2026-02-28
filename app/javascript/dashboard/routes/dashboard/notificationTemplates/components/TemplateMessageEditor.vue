<script setup>
import { ref, computed, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  parseMessageParts,
  VARIABLE_COLORS,
  toToken,
  getSafeOffset,
} from '../constants/variables';

const props = defineProps({
  modelValue: {
    type: String,
    default: '',
  },
  placeholder: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const editorRef = ref(null);
const wrapperRef = ref(null);
const displayValue = ref(props.modelValue);
const lastKnownOffset = ref(0);

watch(
  () => props.modelValue,
  val => {
    displayValue.value = val ?? '';
  },
  { immediate: true }
);

const parts = computed(() => parseMessageParts(displayValue.value));

const getVariableStyle = key => {
  const c = VARIABLE_COLORS[key] ?? { bg: '#e2e8f0', text: '#334155' };
  return {
    backgroundColor: c.bg,
    color: c.text,
  };
};

const getTitle = key =>
  `${t(`NOTIFICATION_TEMPLATES.VARIABLES.${key}_description`)} — ${t('NOTIFICATION_TEMPLATES.VARIABLES.EXAMPLE_PREFIX')} ${t(`NOTIFICATION_TEMPLATES.VARIABLES.${key}_example`)}`;

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
    const elNode = node;
    if (elNode.dataset.type === 'variable' && elNode.dataset.var) {
      s += toToken(elNode.dataset.var);
      return;
    }
    const tag = elNode.tagName.toLowerCase();
    if (tag === 'br') {
      s += '\n';
      return;
    }
    if ((tag === 'div' || tag === 'p') && elNode !== el) {
      if (s.length > 0 && !s.endsWith('\n')) s += '\n';
      elNode.childNodes.forEach(walk);
      return;
    }
    elNode.childNodes.forEach(walk);
  };
  el.childNodes.forEach(walk);
  return s;
};

const setCursorOffset = targetOffset => {
  const el = editorRef.value;
  if (!el) return;
  const sel = window.getSelection();
  if (!sel) return;
  let passed = 0;
  const walkNode = (node, range) => {
    if (node.nodeType === Node.TEXT_NODE) {
      const len = node.textContent.length;
      if (passed + len >= targetOffset) {
        range.setStart(node, targetOffset - passed);
        range.collapse(true);
        return true;
      }
      passed += len;
      return false;
    }
    if (node.nodeType !== Node.ELEMENT_NODE) return false;
    const elNode = node;
    if (elNode.dataset.type === 'variable' && elNode.dataset.var) {
      const len = toToken(elNode.dataset.var).length;
      if (passed + len >= targetOffset) {
        range.setStart(elNode, 0);
        range.collapse(true);
        return true;
      }
      passed += len;
      return false;
    }
    for (let i = 0; i < elNode.childNodes.length; i += 1) {
      if (walkNode(elNode.childNodes[i], range)) return true;
    }
    return false;
  };
  const range = document.createRange();
  if (walkNode(el, range)) {
    sel.removeAllRanges();
    sel.addRange(range);
  }
};

const insertAtCursor = text => {
  const el = editorRef.value;
  const current = serializeFromDom();
  let offset;
  if (!el) {
    offset = current.length;
  } else {
    const sel = window.getSelection();
    const range = sel?.rangeCount ? sel.getRangeAt(0) : null;
    if (range && el.contains(sel.anchorNode)) {
      const preRange = document.createRange();
      preRange.setStart(el, 0);
      preRange.setEnd(sel.anchorNode, sel.anchorOffset);
      offset = preRange.toString().length;
    } else {
      offset = Math.min(lastKnownOffset.value, current.length);
    }
  }
  offset = getSafeOffset(parts.value, offset);
  const before = current.slice(0, offset);
  const after = current.slice(offset);
  displayValue.value = before + text + after;
  emit('update:modelValue', displayValue.value);
  lastKnownOffset.value = offset + text.length;
  nextTick(() => setCursorOffset(offset + text.length));
};

const onInput = () => {
  const str = serializeFromDom();
  if (str !== displayValue.value) {
    displayValue.value = str;
    emit('update:modelValue', str);
  }
  const el = editorRef.value;
  const sel = window.getSelection();
  const range = sel?.rangeCount ? sel.getRangeAt(0) : null;
  if (el && range && el.contains(sel.anchorNode)) {
    const preRange = document.createRange();
    preRange.setStart(el, 0);
    preRange.setEnd(sel.anchorNode, sel.anchorOffset);
    lastKnownOffset.value = preRange.toString().length;
  }
};

const onPaste = e => {
  e.preventDefault();
  const pasted = e.clipboardData?.getData('text/plain') ?? '';
  if (!pasted) return;
  const el = editorRef.value;
  const current = serializeFromDom();
  let offset = current.length;
  if (el) {
    const sel = window.getSelection();
    const range = sel?.rangeCount ? sel.getRangeAt(0) : null;
    if (range && el.contains(sel.anchorNode)) {
      const preRange = document.createRange();
      preRange.setStart(el, 0);
      preRange.setEnd(sel.anchorNode, sel.anchorOffset);
      offset = preRange.toString().length;
    } else {
      offset = Math.min(lastKnownOffset.value, current.length);
    }
  }
  offset = getSafeOffset(parts.value, offset);
  const before = current.slice(0, offset);
  const after = current.slice(offset);
  const newStr = before + pasted + after;
  displayValue.value = newStr;
  emit('update:modelValue', newStr);
  lastKnownOffset.value = offset + pasted.length;
  nextTick(() => setCursorOffset(offset + pasted.length));
};

const onBlur = () => {
  const str = serializeFromDom();
  if (str !== displayValue.value) {
    displayValue.value = str;
    emit('update:modelValue', str);
  }
  const normalized = parseMessageParts(str)
    .map(p => p.value)
    .join('');
  if (normalized !== str) {
    displayValue.value = normalized;
    emit('update:modelValue', normalized);
  }
};

const getOffsetAfterNode = (root, targetNode) => {
  const range = document.createRange();
  range.setStart(root, 0);
  range.setEndAfter(targetNode);
  return range.toString().length;
};

const getDropOffset = e => {
  const el = editorRef.value;
  if (!el) return 0;
  let range = null;
  if (document.caretRangeFromPoint) {
    range = document.caretRangeFromPoint(e.clientX, e.clientY);
  } else if (document.caretPositionFromPoint) {
    const pos = document.caretPositionFromPoint(e.clientX, e.clientY);
    if (pos) {
      range = document.createRange();
      range.setStart(pos.offsetNode, pos.offset);
      range.collapse(true);
    }
  }
  if (!range || !el.contains(range.startContainer)) return 0;
  let node = range.startContainer;
  if (node.nodeType === Node.TEXT_NODE) node = node.parentNode;
  while (node && node !== el) {
    if (node.dataset?.type === 'variable') {
      return getOffsetAfterNode(el, node);
    }
    node = node.parentNode;
  }
  const preRange = document.createRange();
  preRange.setStart(el, 0);
  preRange.setEnd(range.startContainer, range.startOffset);
  return preRange.toString().length;
};

const onDragOver = e => {
  e.preventDefault();
  if (e.dataTransfer) e.dataTransfer.dropEffect = 'copy';
};

const onDrop = e => {
  e.preventDefault();
  const text = e.dataTransfer?.getData('text/plain') ?? '';
  if (!text || !/^@\w+$/.test(text)) return;
  const current = serializeFromDom();
  const dropOffset = getDropOffset(e);
  const safeOffset = getSafeOffset(parts.value, dropOffset);
  const before = current.slice(0, safeOffset);
  const after = current.slice(safeOffset);
  const newStr = before + text + after;
  displayValue.value = newStr;
  emit('update:modelValue', newStr);
  lastKnownOffset.value = safeOffset + text.length;
  nextTick(() => setCursorOffset(safeOffset + text.length));
};

const onVariableSpanClick = idx => {
  const offsetAfter = parts.value
    .slice(0, idx + 1)
    .reduce((sum, p) => sum + (p.value?.length ?? 0), 0);
  lastKnownOffset.value = offsetAfter;
  nextTick(() => setCursorOffset(offsetAfter));
};

const focus = () => editorRef.value?.focus();

defineExpose({ insertAtCursor, focus });
</script>

<template>
  <div ref="wrapperRef" class="min-h-24 w-full">
    <div
      ref="editorRef"
      contenteditable="true"
      role="textbox"
      :data-placeholder="placeholder"
      class="min-h-24 w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none transition-colors resize-none break-words empty:before:content-[attr(data-placeholder)] empty:before:text-n-slate-9"
      @blur="onBlur"
      @input="onInput"
      @paste="onPaste"
      @dragover="onDragOver"
      @drop="onDrop"
    >
      <template v-for="(part, idx) in parts" :key="idx">
        <span
          v-if="part.type === 'variable'"
          :title="getTitle(part.key)"
          data-type="variable"
          :data-var="part.key"
          contenteditable="false"
          class="inline rounded px-0.5 font-medium align-baseline"
          :style="getVariableStyle(part.key)"
          @click="onVariableSpanClick(idx)"
        >
          {{ part.value }}
        </span>
        <br v-else-if="part.type === 'newline'" />
        <span v-else data-type="text">{{ part.value }}</span>
      </template>
    </div>
  </div>
</template>
