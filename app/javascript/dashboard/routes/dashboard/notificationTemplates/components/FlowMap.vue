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
  const colArrays = Array.from({ length: maxCol + 1 }, (_, c) =>
    tmpls.filter(t => col[t.id] === c)
  );
  // Predecessor map (reuse out[] from above)
  const preds = Object.fromEntries(ids.map(id => [id, []]));
  ids.forEach(srcId => out[srcId].forEach(tgtId => preds[tgtId].push(srcId)));

  for (let iter = 0; iter < 3; iter += 1) {
    // Forward pass: sort by average predecessor position in previous column
    for (let c = 1; c <= maxCol; c += 1) {
      const pos = Object.fromEntries(colArrays[c - 1].map((t, i) => [t.id, i]));
      colArrays[c].sort((a, b) => {
        const avg = nodeIds => {
          const f = nodeIds.filter(id => pos[id] !== undefined);
          return f.length
            ? f.reduce((s, id) => s + pos[id], 0) / f.length
            : Infinity;
        };
        return avg(preds[a.id]) - avg(preds[b.id]);
      });
    }
    // Backward pass: sort by average successor position in next column
    for (let c = maxCol - 1; c >= 0; c -= 1) {
      const pos = Object.fromEntries(colArrays[c + 1].map((t, i) => [t.id, i]));
      colArrays[c].sort((a, b) => {
        const avg = nodeIds => {
          const f = nodeIds.filter(id => pos[id] !== undefined);
          return f.length
            ? f.reduce((s, id) => s + pos[id], 0) / f.length
            : Infinity;
        };
        return avg(out[a.id]) - avg(out[b.id]);
      });
    }
  }
  return colArrays;
});

// Map: templateId -> column index (used in computeArrows for bypass routing)
const colOf = computed(() => {
  const map = {};
  columns.value.forEach((col, ci) =>
    col.forEach(t => {
      map[t.id] = ci;
    })
  );
  return map;
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
const LANE_OFFSET_STEP = 12;
const GAP_MARGIN = 8;
const BYPASS_BASE = 48; // px above topmost block to first bypass lane
const BYPASS_GAP = 14; // vertical spacing between bypass lanes

const computeArrows = async () => {
  await nextTick();
  if (!containerRef.value) return;
  const cr = containerRef.value.getBoundingClientRect();
  const colOfMap = colOf.value;
  const raw = [];

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
      const routeX = goRight
        ? (sr.right + tr.left) / 2 - cr.left
        : (tr.right + sr.left) / 2 - cr.left;
      const gapMinX = goRight
        ? sr.right - cr.left + GAP_MARGIN
        : tr.right - cr.left + GAP_MARGIN;
      const gapMaxX = goRight
        ? tr.left - cr.left - GAP_MARGIN
        : sr.left - cr.left - GAP_MARGIN;

      const srcCol = colOfMap[tmpl.id] ?? 0;
      const tgtCol = colOfMap[btn.templateId] ?? 0;
      raw.push({
        id: `${tmpl.id}-${btn.id}`,
        srcCol,
        tgtCol,
        span: Math.abs(tgtCol - srcCol),
        routeX,
        gapMinX,
        gapMaxX,
        x1,
        y1,
        x2,
        y2,
        goRight,
      });
    });
  });

  // Global top of all blocks — bypass lanes route above this
  let globalTop = Infinity;
  Object.values(nodeRefs.value).forEach(el => {
    const r = el.getBoundingClientRect();
    if (r.width > 0) globalTop = Math.min(globalTop, r.top - cr.top);
  });
  if (!Number.isFinite(globalTop)) globalTop = 0;

  const R = 8;
  const result = [];

  // --- Spanning arrows (|span| != 1): bypass routing above all blocks ---
  const spanning = raw.filter(e => e.span !== 1);
  // Sort by x1 so bypass lanes don't cross each other
  spanning.sort((a, b) => a.x1 - b.x1);
  spanning.forEach((entry, index) => {
    const by = globalTop - BYPASS_BASE - index * BYPASS_GAP;
    const { x1, y1, x2, y2, goRight } = entry;
    const cx1 = goRight ? x1 + R : x1 - R;
    const cx2 = goRight ? x2 - R : x2 + R;
    const d = [
      `M ${x1} ${y1}`,
      `V ${by + R}`,
      `Q ${x1} ${by} ${cx1} ${by}`,
      `H ${cx2}`,
      `Q ${x2} ${by} ${x2} ${by + R}`,
      `V ${y2}`,
    ].join(' ');
    result.push({ id: entry.id, d, bypass: true });
  });

  // --- Adjacent arrows (span == 1): S-curve routing through column gap ---
  const adjacent = raw.filter(e => e.span === 1);
  const byGap = {};
  adjacent.forEach(e => {
    const key = `${Math.min(e.srcCol, e.tgtCol)}-${Math.max(e.srcCol, e.tgtCol)}`;
    (byGap[key] ??= []).push(e);
  });
  Object.values(byGap).forEach(group => {
    group.sort((a, b) => (a.y1 + a.y2) / 2 - (b.y1 + b.y2) / 2);
    group.forEach((entry, index) => {
      const n = group.length;
      const rx = Math.max(
        entry.gapMinX,
        Math.min(
          entry.gapMaxX,
          entry.routeX + (index - (n - 1) / 2) * LANE_OFFSET_STEP
        )
      );
      const { x1, y1, x2, y2, goRight } = entry;
      const dy = y2 - y1;
      let d;
      if (Math.abs(dy) < R * 2) {
        d = `M ${x1} ${y1} H ${x2}`;
      } else {
        const s = dy > 0 ? 1 : -1;
        d = [
          `M ${x1} ${y1}`,
          `H ${goRight ? rx - R : rx + R}`,
          `Q ${rx} ${y1} ${rx} ${y1 + s * R}`,
          `V ${y2 - s * R}`,
          `Q ${rx} ${y2} ${goRight ? rx + R : rx - R} ${y2}`,
          `H ${x2}`,
        ].join(' ');
      }
      result.push({ id: entry.id, d, bypass: false });
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
    <!-- Canvas: centered, panned via transform, SVG + cards inside -->
    <div
      ref="containerRef"
      class="absolute left-1/2 top-1/2 flex gap-32 px-10 pt-32 pb-10"
      :style="{
        transform: `translate(calc(-50% + ${panX}px), calc(-50% + ${panY}px))`,
      }"
    >
      <!-- SVG arrows on top of cards so lines are always visible -->
      <svg
        class="absolute inset-0 w-full h-full overflow-visible pointer-events-none z-20"
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
          :stroke="a.bypass ? '#94a3b8' : '#334155'"
          stroke-width="1.5"
          :stroke-dasharray="a.bypass ? '6 3' : 'none'"
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
