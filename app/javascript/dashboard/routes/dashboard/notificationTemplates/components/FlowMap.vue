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

// Assign columns via topological longest-path: source (with button) → left, target → right
const columns = computed(() => {
  const tmpls = props.templates;
  if (!tmpls.length) return [];

  const ids = tmpls.map(t => t.id);
  const out = Object.fromEntries(ids.map(id => [id, []]));
  const indeg = Object.fromEntries(ids.map(id => [id, 0]));

  tmpls.forEach(t => {
    t.buttons?.forEach(btn => {
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

const containerRef = ref(null);
const nodeRefs = ref({});
const btnRefs = ref({});
const arrows = ref([]);

const computeArrows = async () => {
  await nextTick();
  if (!containerRef.value) return;
  const cr = containerRef.value.getBoundingClientRect();
  const result = [];

  props.templates.forEach(tmpl => {
    tmpl.buttons?.forEach(btn => {
      if (btn.type !== 'template' || !btn.templateId) return;
      const bEl = btnRefs.value[`${tmpl.id}-${btn.id}`];
      const tEl = nodeRefs.value[btn.templateId];
      if (!bEl || !tEl) return;

      const br = bEl.getBoundingClientRect();
      const tr = tEl.getBoundingClientRect();
      if (br.width === 0 || tr.width === 0) return;

      // Left-to-right: from right edge of button row → left edge of target card
      // Right-to-left: from left edge of button row → right edge of target card
      const goRight = br.right <= tr.left;
      const x1 = (goRight ? br.right : br.left) - cr.left;
      const y1 = (br.top + br.bottom) / 2 - cr.top;
      const x2 = (goRight ? tr.left : tr.right) - cr.left;
      const y2 = (tr.top + tr.bottom) / 2 - cr.top;

      // Orthogonal elbow with rounded corners (8px radius)
      const r = 8;
      const midX = (x1 + x2) / 2;
      const dy = y2 - y1;
      let d;

      if (Math.abs(dy) < r * 2) {
        d = `M ${x1} ${y1} H ${x2}`;
      } else {
        const s = dy > 0 ? 1 : -1;
        d = [
          `M ${x1} ${y1}`,
          `H ${midX - r}`,
          `Q ${midX} ${y1} ${midX} ${y1 + s * r}`,
          `V ${y2 - s * r}`,
          `Q ${midX} ${y2} ${midX + r} ${y2}`,
          `H ${x2}`,
        ].join(' ');
      }

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
});
onBeforeUnmount(() => ro?.disconnect());
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
const firstMessage = tmpl => tmpl.messages?.[0] ?? tmpl.messageText ?? '';

const preview = txt => {
  if (!txt) return '';
  const s = txt.replace(/\{(\w+)\}/g, (_, v) => VARS[v] ?? v);
  return s.length > 80 ? `${s.slice(0, 80)}…` : s;
};
</script>

<template>
  <div
    class="h-full overflow-auto bg-[#f8fafc] [background-image:radial-gradient(circle,_#cbd5e1_1.5px,transparent_1.5px)] [background-size:24px_24px]"
  >
    <div
      ref="containerRef"
      class="relative flex gap-32 p-10 min-w-max min-h-full"
    >
      <!-- SVG arrows layer (pointer-events-none so cards remain clickable) -->
      <svg
        class="absolute inset-0 pointer-events-none z-20 w-full h-full overflow-visible"
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
          class="w-60 rounded-2xl border border-n-strong bg-n-solid-1 shadow-sm cursor-pointer overflow-hidden transition-shadow hover:shadow-md"
          :class="{ 'opacity-50': !tmpl.enabled }"
          @click="emit('edit', tmpl)"
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
            v-if="firstMessage(tmpl)"
            class="px-4 py-2.5 border-t border-n-weak text-xs text-n-slate-11 leading-relaxed"
          >
            {{ preview(firstMessage(tmpl)) }}
          </div>

          <!-- Attachments row -->
          <div
            v-if="tmpl.attachments?.length"
            class="px-4 py-2 border-t border-n-weak flex items-center gap-1.5 text-xs text-n-slate-9"
          >
            <span class="i-lucide-paperclip size-3 flex-shrink-0" />
            <span>{{ tmpl.attachments.length }}</span>
          </div>

          <!-- Button rows — arrows originate from right edge of each row -->
          <div
            v-for="btn in tmpl.buttons"
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
