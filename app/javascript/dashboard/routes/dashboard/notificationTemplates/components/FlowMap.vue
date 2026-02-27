<script setup>
import {
  ref,
  computed,
  onMounted,
  onBeforeUnmount,
  nextTick,
  watch,
} from 'vue';

const props = defineProps({
  templates: { type: Array, default: () => [] },
});
const emit = defineEmits(['edit']);

const TYPE_COLOR = {
  event: '#a5b4fc',
  time: '#fdba74',
  lost_clients: '#f9a8d4',
  client_consent: '#86efac',
};
const typeColor = type => TYPE_COLOR[type] ?? '#cbd5e1';

// First message block: text, buttons, attachments (messages[0] or template root)
const getMessageBlock = tmpl => {
  const first = tmpl.messages?.[0];
  if (first && typeof first === 'object') {
    return {
      text: first.text ?? tmpl.messageText ?? '',
      buttons: first.buttons ?? tmpl.buttons ?? [],
      attachments: first.attachments ?? tmpl.attachments ?? [],
    };
  }
  return {
    text: tmpl.messageText ?? '',
    buttons: tmpl.buttons ?? [],
    attachments: tmpl.attachments ?? [],
  };
};

// Assign columns via topological longest-path: source (with button) → left, target → right
const columns = computed(() => {
  const tmpls = props.templates;
  if (!tmpls.length) return [];

  const ids = tmpls.map(t => t.id);
  const out = Object.fromEntries(ids.map(id => [id, []]));
  const indeg = Object.fromEntries(ids.map(id => [id, 0]));

  tmpls.forEach(t => {
    getMessageBlock(t).buttons.forEach(btn => {
      if (
        btn.type === 'template' &&
        btn.templateId &&
        ids.includes(btn.templateId)
      ) {
        out[t.id].push(btn.templateId);
        indeg[btn.templateId] += 1;
      }
    });
  });

  const col = Object.fromEntries(ids.map(id => [id, 0]));
  const deg = { ...indeg };
  const queue = ids.filter(id => deg[id] === 0);
  let h = 0;
  while (h < queue.length) {
    const id = queue[h];
    h += 1;
    out[id].forEach(tgt => {
      col[tgt] = Math.max(col[tgt], col[id] + 1);
      deg[tgt] -= 1;
      if (deg[tgt] === 0) queue.push(tgt);
    });
  }

  const maxCol = Math.max(0, ...Object.values(col));
  return Array.from({ length: maxCol + 1 }, (_, c) =>
    tmpls.filter(t => col[t.id] === c)
  );
});

// Refs
const outerRef = ref(null);
const containerRef = ref(null); // translated canvas — arrow coords relative to this
const nodeRefs = ref({});
const btnRefs = ref({});
const arrows = ref([]);

// Pan state
const isPanning = ref(false);
const hasDragged = ref(false);
const panX = ref(0);
const panY = ref(0);
let dragStartX = 0;
let dragStartY = 0;

const onMouseDown = e => {
  if (e.button !== 0) return;
  isPanning.value = true;
  hasDragged.value = false;
  dragStartX = e.clientX - panX.value;
  dragStartY = e.clientY - panY.value;
};

const onMouseMove = e => {
  if (!isPanning.value) return;
  e.preventDefault();
  const nx = e.clientX - dragStartX;
  const ny = e.clientY - dragStartY;
  if (
    !hasDragged.value &&
    Math.abs(nx - panX.value) + Math.abs(ny - panY.value) > 4
  ) {
    hasDragged.value = true;
  }
  panX.value = nx;
  panY.value = ny;
};

const stopPan = () => {
  isPanning.value = false;
};

// Arrow computation — coords relative to containerRef (the canvas)
const computeArrows = async () => {
  await nextTick();
  if (!containerRef.value) return;
  const cr = containerRef.value.getBoundingClientRect();
  const result = [];

  props.templates.forEach(tmpl => {
    getMessageBlock(tmpl).buttons.forEach(btn => {
      if (btn.type !== 'template' || !btn.templateId) return;
      const bEl = btnRefs.value[`${tmpl.id}-${btn.id}`];
      const tEl = nodeRefs.value[btn.templateId];
      const sEl = nodeRefs.value[tmpl.id];
      if (!bEl || !tEl || !sEl) return;

      const br = bEl.getBoundingClientRect();
      const tr = tEl.getBoundingClientRect();
      const sr = sEl.getBoundingClientRect();
      if (br.width === 0 || tr.width === 0) return;

      const goRight = sr.right <= tr.left;
      const x1 = (goRight ? br.right : br.left) - cr.left;
      const y1 = (br.top + br.bottom) / 2 - cr.top;
      const x2 = (goRight ? tr.left : tr.right) - cr.left;
      const y2 = (tr.top + tr.bottom) / 2 - cr.top;

      // Smooth cubic Bezier: horizontal exit, horizontal entry, curve in the gap
      const dx = x2 - x1;
      const ctrl = Math.min(80, Math.abs(dx) * 0.4);
      const cp1x = goRight ? x1 + ctrl : x1 - ctrl;
      const cp2x = goRight ? x2 - ctrl : x2 + ctrl;
      const d = `M ${x1} ${y1} C ${cp1x} ${y1}, ${cp2x} ${y2}, ${x2} ${y2}`;

      result.push({ id: `${tmpl.id}-${btn.id}`, d });
    });
  });

  arrows.value = result;
};

let ro = null;
onMounted(async () => {
  await nextTick();
  await computeArrows();
  ro = new ResizeObserver(computeArrows);
  if (containerRef.value) ro.observe(containerRef.value);
  window.addEventListener('mouseup', stopPan);
});
onBeforeUnmount(() => {
  ro?.disconnect();
  window.removeEventListener('mouseup', stopPan);
});
watch(() => props.templates, computeArrows, { deep: true });

const VARS = {
  client_name: 'Иван',
  service_name: 'Стрижка',
  date: '15 марта',
  time: '14:30',
  branch_name: 'Центр',
  master_name: 'Мария',
  price: '1 500 ₽',
};
const BG_STYLE = {
  backgroundColor: '#f8fafc',
  backgroundImage: 'radial-gradient(circle, #cbd5e1 1.5px, transparent 1.5px)',
  backgroundSize: '24px 24px',
};

const preview = txt => {
  if (!txt) return '';
  const s = txt.replace(/\{(\w+)\}/g, (_, v) => VARS[v] ?? v);
  return s.length > 80 ? `${s.slice(0, 80)}…` : s;
};
</script>

<template>
  <!-- Outer viewport: clips overflow, handles mouse events -->
  <div
    ref="outerRef"
    class="h-full w-full overflow-hidden relative select-none"
    :class="isPanning ? 'cursor-grabbing' : 'cursor-grab'"
    :style="BG_STYLE"
    @mousedown="onMouseDown"
    @mousemove="onMouseMove"
    @mouseup="stopPan"
  >
    <!-- Canvas: panned via transform, SVG + cards inside -->
    <div
      ref="containerRef"
      class="absolute flex gap-32 p-10"
      :style="{ transform: `translate(${panX}px, ${panY}px)` }"
    >
      <!-- SVG arrows behind cards so lines wrap around blocks -->
      <svg
        class="absolute inset-0 w-full h-full overflow-visible pointer-events-none z-0"
      >
        <defs>
          <marker
            id="flowArr"
            markerWidth="8"
            markerHeight="6"
            refX="7.5"
            refY="3"
            orient="auto"
          >
            <polygon points="0 0, 8 3, 0 6" fill="#334155" />
          </marker>
        </defs>
        <path
          v-for="a in arrows"
          :key="a.id"
          :d="a.d"
          fill="none"
          stroke="#334155"
          stroke-width="1.5"
          marker-end="url(#flowArr)"
        />
      </svg>

      <!-- Columns -->
      <div
        v-for="(col, ci) in columns"
        :key="ci"
        class="relative z-10 flex flex-col gap-5"
      >
        <!-- Template card -->
        <div
          v-for="tmpl in col"
          :key="tmpl.id"
          :ref="
            el => {
              if (el) nodeRefs[tmpl.id] = el;
              else delete nodeRefs[tmpl.id];
            }
          "
          class="w-60 rounded-2xl border border-n-strong bg-n-solid-1 shadow-sm overflow-hidden transition-shadow hover:shadow-md"
          :class="[
            { 'opacity-50': !tmpl.enabled },
            isPanning ? '' : 'cursor-pointer',
          ]"
          @click="!hasDragged && emit('edit', tmpl)"
        >
          <!-- Type-colored header -->
          <div
            class="px-4 py-2.5"
            :style="{ background: typeColor(tmpl.type) }"
          >
            <p class="text-sm font-semibold text-n-slate-12 truncate">
              {{ tmpl.name }}
            </p>
          </div>

          <!-- Message preview row -->
          <div
            v-if="getMessageBlock(tmpl).text"
            class="px-4 py-2.5 border-t border-n-weak text-xs text-n-slate-11 leading-relaxed"
          >
            {{ preview(getMessageBlock(tmpl).text) }}
          </div>

          <!-- Attachments row -->
          <div
            v-if="getMessageBlock(tmpl).attachments.length"
            class="px-4 py-2 border-t border-n-weak flex items-center gap-1.5 text-xs text-n-slate-9"
          >
            <span class="i-lucide-paperclip size-3 flex-shrink-0" />
            <span>{{ getMessageBlock(tmpl).attachments.length }}</span>
          </div>

          <!-- Button rows — arrows originate from right edge of each row -->
          <div
            v-for="btn in getMessageBlock(tmpl).buttons"
            :key="btn.id"
            :ref="
              el => {
                const k = `${tmpl.id}-${btn.id}`;
                if (el) btnRefs[k] = el;
                else delete btnRefs[k];
              }
            "
            class="px-4 py-2 border-t border-n-weak flex items-center gap-2 text-xs"
            :class="
              btn.type === 'template'
                ? 'text-n-blue-11 font-medium'
                : 'text-n-slate-10'
            "
          >
            <span
              class="flex-shrink-0"
              :class="
                btn.type === 'template'
                  ? 'i-lucide-arrow-right-circle size-3.5'
                  : 'i-lucide-external-link size-3.5'
              "
            />
            <span class="truncate">{{ btn.label }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
