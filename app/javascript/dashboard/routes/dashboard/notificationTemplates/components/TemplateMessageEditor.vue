<script setup>
import { ref, computed, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  parseMessageParts,
  VARIABLE_COLORS,
  toToken,
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

const emit = defineEmits([
  'update:modelValue',
  'dragVariableStart',
  'dragVariableEnd',
  'highlightVariable',
]);

const { t } = useI18n();
const editorRef = ref(null);
const wrapperRef = ref(null);
const displayValue = ref(props.modelValue);
const isDragging = ref(false);
const showDropCaret = ref(false);
const dropCaretStyle = ref({ left: 0, top: 0, height: 0 });

watch(
  () => props.modelValue,
  val => {
    displayValue.value = val ?? '';
  },
  { immediate: true }
);

const parts = computed(() => parseMessageParts(displayValue.value));

const getChipStyle = key => {
  const c = VARIABLE_COLORS[key] ?? { bg: '#e2e8f0', text: '#334155' };
  return {
    backgroundColor: c.bg,
    color: c.text,
    borderColor: c.border || c.bg,
  };
};

const getTitle = key =>
  `${t(`NOTIFICATION_TEMPLATES.VARIABLES.${key}_description`)} — ${t('NOTIFICATION_TEMPLATES.VARIABLES.EXAMPLE_PREFIX')} ${t(`NOTIFICATION_TEMPLATES.VARIABLES.${key}_example`)}`;

const removeVariable = index => {
  const newParts = parts.value.filter((_, i) => i !== index);
  const newStr = newParts.map(p => p.value).join('');
  displayValue.value = newStr;
  emit('update:modelValue', newStr);
};

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
  if (!el) {
    displayValue.value += text;
    emit('update:modelValue', displayValue.value);
    return;
  }
  const sel = window.getSelection();
  const range = sel?.rangeCount ? sel.getRangeAt(0) : null;
  if (!range || !el.contains(sel.anchorNode)) {
    displayValue.value += text;
    emit('update:modelValue', displayValue.value);
    return;
  }
  const preRange = document.createRange();
  preRange.setStart(el, 0);
  preRange.setEnd(sel.anchorNode, sel.anchorOffset);
  const offset = preRange.toString().length;
  const current = serializeFromDom();
  const before = current.slice(0, offset);
  const after = current.slice(offset);
  displayValue.value = before + text + after;
  emit('update:modelValue', displayValue.value);
  nextTick(() => setCursorOffset(offset + text.length));
};

const onBlur = () => {
  const str = serializeFromDom();
  if (str !== displayValue.value) {
    displayValue.value = str;
    emit('update:modelValue', str);
  }
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
  const preRange = document.createRange();
  preRange.setStart(el, 0);
  preRange.setEnd(range.startContainer, range.startOffset);
  return preRange.toString().length;
};

const onDrop = e => {
  e.preventDefault();
  const text = e.dataTransfer?.getData('text/plain');
  const fromEditor = e.dataTransfer?.getData(
    'application/x-notification-template-variable'
  );
  if (!text || !/^\{\w+\}$/.test(text)) return;
  if (fromEditor) {
    const current = serializeFromDom();
    const token = text;
    const firstIdx = current.indexOf(token);
    if (firstIdx === -1) {
      insertAtCursor(text);
      return;
    }
    const dropOffset = getDropOffset(e);
    const afterRemoval =
      current.slice(0, firstIdx) + current.slice(firstIdx + token.length);
    const insertOffset =
      dropOffset > firstIdx ? dropOffset - token.length : dropOffset;
    const clamped = Math.max(0, Math.min(insertOffset, afterRemoval.length));
    const newStr =
      afterRemoval.slice(0, clamped) + token + afterRemoval.slice(clamped);
    displayValue.value = newStr;
    emit('update:modelValue', newStr);
    nextTick(() => setCursorOffset(clamped + token.length));
  } else {
    insertAtCursor(text);
  }
  showDropCaret.value = false;
  emit('dragVariableEnd');
};

const createDragImage = (token, key) => {
  const el = document.createElement('div');
  el.textContent = token;
  const c = VARIABLE_COLORS[key] ?? { bg: '#e2e8f0', text: '#334155' };
  el.style.cssText = `
    position: absolute; left: -9999px; top: 0;
    padding: 2px 6px; border-radius: 9999px; font-size: 11px; font-weight: 500;
    background-color: ${c.bg}; color: ${c.text}; border: 1px solid ${c.border || c.bg};
    opacity: 0.6; pointer-events: none; white-space: nowrap;
  `;
  document.body.appendChild(el);
  return el;
};

const onVariableDragStart = (e, key) => {
  const token = toToken(key);
  e.dataTransfer?.setData('text/plain', token);
  e.dataTransfer?.setData('application/x-notification-template-variable', key);
  e.dataTransfer.effectAllowed = 'move';
  isDragging.value = true;
  const dragImage = createDragImage(token, key);
  e.dataTransfer?.setDragImage(dragImage, 0, 0);
  requestAnimationFrame(() => dragImage.remove());
  emit('dragVariableStart', key);
};

const onVariableDragEnd = () => {
  isDragging.value = false;
  showDropCaret.value = false;
  emit('dragVariableEnd');
};

const onVariableMouseEnter = key => {
  if (!isDragging.value) emit('highlightVariable', key);
};

const onVariableMouseLeave = () => {
  if (!isDragging.value) emit('highlightVariable', null);
};

const getRangeAtPoint = (x, y) => {
  if (document.caretRangeFromPoint) {
    return document.caretRangeFromPoint(x, y);
  }
  if (document.caretPositionFromPoint) {
    const pos = document.caretPositionFromPoint(x, y);
    if (!pos) return null;
    const r = document.createRange();
    r.setStart(pos.offsetNode, pos.offset);
    r.collapse(true);
    return r;
  }
  return null;
};

const onDragOver = e => {
  e.preventDefault();
  e.dataTransfer.dropEffect = 'move';
  if (!e.dataTransfer?.types?.includes('text/plain')) return;
  const el = editorRef.value;
  const wrapper = wrapperRef.value;
  if (!el || !wrapper) return;
  const range = getRangeAtPoint(e.clientX, e.clientY);
  if (!range || !el.contains(range.startContainer)) {
    showDropCaret.value = false;
    return;
  }
  const rangeRect = range.getBoundingClientRect();
  const wrapperRect = wrapper.getBoundingClientRect();
  dropCaretStyle.value = {
    left: rangeRect.left - wrapperRect.left + wrapper.scrollLeft,
    top: rangeRect.top - wrapperRect.top + wrapper.scrollTop,
    height: rangeRect.height || 16,
  };
  showDropCaret.value = true;
};

const onDragLeave = () => {
  showDropCaret.value = false;
};

const focus = () => editorRef.value?.focus();

defineExpose({ insertAtCursor, focus });
</script>

<template>
  <div ref="wrapperRef" class="relative min-h-24 w-full">
    <div
      ref="editorRef"
      contenteditable="true"
      role="textbox"
      :data-placeholder="placeholder"
      class="min-h-24 w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none transition-colors resize-none break-words empty:before:content-[attr(data-placeholder)] empty:before:text-n-slate-9"
      @blur="onBlur"
      @dragover="onDragOver"
      @dragleave="onDragLeave"
      @drop="onDrop"
    >
      <template v-for="(part, idx) in parts" :key="idx">
        <span
          v-if="part.type === 'variable'"
          :title="getTitle(part.key)"
          data-type="variable"
          :data-var="part.key"
          contenteditable="false"
          draggable="true"
          class="inline-flex items-center gap-0.5 rounded-full px-1.5 py-px text-[11px] font-medium border align-baseline mr-0.5 leading-none cursor-grab active:cursor-grabbing"
          :style="getChipStyle(part.key)"
          @dragstart="onVariableDragStart($event, part.key)"
          @dragend="onVariableDragEnd"
          @mouseenter="onVariableMouseEnter(part.key)"
          @mouseleave="onVariableMouseLeave"
        >
          {{ part.value }}
          <button
            type="button"
            class="ml-0.5 rounded-full p-px opacity-60 hover:opacity-100 hover:bg-black/10 focus:outline-none"
            :aria-label="t('NOTIFICATION_TEMPLATES.VARIABLES.REMOVE_ARIA')"
            @click.stop="removeVariable(idx)"
          >
            <span class="i-lucide-x size-2.5" />
          </button>
        </span>
        <br v-else-if="part.type === 'newline'" />
        <span v-else data-type="text">{{ part.value }}</span>
      </template>
    </div>
    <div
      v-show="showDropCaret"
      class="absolute w-0.5 bg-n-brand pointer-events-none animate-pulse"
      :style="{
        left: `${dropCaretStyle.left}px`,
        top: `${dropCaretStyle.top}px`,
        height: `${dropCaretStyle.height}px`,
      }"
      aria-hidden="true"
    />
  </div>
</template>
