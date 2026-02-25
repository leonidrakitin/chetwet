<script setup>
import { ref, onMounted, onBeforeUnmount, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import NotificationTemplatePreview from './NotificationTemplatePreview.vue';

const props = defineProps({
  templates: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['edit']);

const { t } = useI18n();

const containerRef = ref(null);
const nodeRefs = ref({});
const arrows = ref([]);
const hoveredTemplate = ref(null);
const highlightedId = ref(null);

const EXAMPLE_VALUES = {
  client_name: 'Иван Иванов',
  service_name: 'Стрижка',
  branch_name: 'Центральный офис',
  master_name: 'Мария',
  price: '1 500 ₽',
  date: '15 марта',
  time: '14:30',
};

const getPreviewText = text => {
  if (!text) return '';
  const processed = text.replace(
    /\{(\w+)\}/g,
    (match, v) => EXAMPLE_VALUES[v] ?? match
  );
  return processed.length > 80 ? processed.slice(0, 80) + '...' : processed;
};

const getTemplateName = id => {
  const found = props.templates.find(tmpl => tmpl.id === id);
  return found?.name ?? String(id);
};

// Compute arrows from template buttons of type 'template'
const computeArrows = () => {
  if (!containerRef.value) return;
  const containerRect = containerRef.value.getBoundingClientRect();
  const newArrows = [];

  props.templates.forEach(tmpl => {
    if (!tmpl.buttons?.length) return;
    const sourceEl = nodeRefs.value[tmpl.id];
    if (!sourceEl) return;
    const sourceRect = sourceEl.getBoundingClientRect();

    tmpl.buttons.forEach(btn => {
      if (btn.type !== 'template' || !btn.templateId) return;
      const targetEl = nodeRefs.value[btn.templateId];
      if (!targetEl) return;
      const targetRect = targetEl.getBoundingClientRect();

      const x1 = sourceRect.right - containerRect.left;
      const y1 = sourceRect.top + sourceRect.height / 2 - containerRect.top;
      const x2 = targetRect.left - containerRect.left;
      const y2 = targetRect.top + targetRect.height / 2 - containerRect.top;
      const dx = Math.min(80, Math.abs(x2 - x1) / 2);
      const cx1 = x1 + dx;
      const cy1 = y1;
      const cx2 = x2 - dx;
      const cy2 = y2;

      newArrows.push({
        id: `${tmpl.id}-${btn.id}`,
        d: `M ${x1} ${y1} C ${cx1} ${cy1}, ${cx2} ${cy2}, ${x2} ${y2}`,
        sourceId: tmpl.id,
        targetId: btn.templateId,
      });
    });
  });
  arrows.value = newArrows;
};

const onNodeClick = template => {
  emit('edit', template);
};

const onNodeHover = template => {
  hoveredTemplate.value = template;
};

const onNodeLeave = () => {
  hoveredTemplate.value = null;
};

const scrollToTemplate = id => {
  const el = nodeRefs.value[id];
  if (el) {
    el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    highlightedId.value = id;
    setTimeout(() => {
      highlightedId.value = null;
    }, 2000);
  }
};

let resizeObserver = null;

onMounted(async () => {
  await nextTick();
  computeArrows();
  resizeObserver = new ResizeObserver(() => {
    computeArrows();
  });
  if (containerRef.value) {
    resizeObserver.observe(containerRef.value);
  }
});

onBeforeUnmount(() => {
  resizeObserver?.disconnect();
});

defineExpose({ scrollToTemplate });
</script>

<template>
  <div class="flex gap-4 h-full overflow-hidden">
    <!-- Flow canvas -->
    <div ref="containerRef" class="flex-1 overflow-auto relative">
      <!-- SVG arrows overlay -->
      <svg class="absolute inset-0 w-full h-full pointer-events-none z-10">
        <defs>
          <marker
            id="arrowhead"
            markerWidth="10"
            markerHeight="7"
            refX="9"
            refY="3.5"
            orient="auto"
          >
            <polygon points="0 0, 10 3.5, 0 7" class="fill-n-blue-9" />
          </marker>
        </defs>
        <path
          v-for="arrow in arrows"
          :key="arrow.id"
          :d="arrow.d"
          fill="none"
          class="stroke-n-blue-9"
          stroke-width="1.5"
          stroke-dasharray="4 2"
          marker-end="url(#arrowhead)"
        />
      </svg>

      <!-- Template nodes grid -->
      <div
        class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 p-4 relative z-20"
      >
        <div
          v-for="template in templates"
          :key="template.id"
          :ref="
            el => {
              if (el) nodeRefs[template.id] = el;
            }
          "
          class="flex flex-col gap-2 p-3 rounded-xl border bg-n-solid-1 cursor-pointer transition-all duration-200"
          :class="{
            'border-n-brand ring-2 ring-n-brand ring-offset-2 animate-pulse':
              highlightedId === template.id,
            'border-n-weak hover:border-n-strong':
              highlightedId !== template.id,
          }"
          @click="onNodeClick(template)"
          @mouseenter="onNodeHover(template)"
          @mouseleave="onNodeLeave"
        >
          <!-- Header -->
          <div class="flex items-center justify-between gap-2">
            <span class="text-xs font-semibold text-n-slate-12 truncate">{{
              template.name
            }}</span>
            <span
              class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-n-brand/10 text-n-blue-11 flex-shrink-0"
            >
              {{ template.type }}
            </span>
          </div>

          <!-- Mini message bubble -->
          <div
            v-if="template.messageText"
            class="rounded-lg bg-n-brand px-2.5 py-1.5 text-xs text-white leading-relaxed line-clamp-2"
          >
            {{ getPreviewText(template.messageText) }}
          </div>

          <!-- Attachments count -->
          <div
            v-if="template.attachments?.length"
            class="flex items-center gap-1 text-xs text-n-slate-10"
          >
            <span class="i-lucide-paperclip size-3" />
            {{ template.attachments.length }}
          </div>

          <!-- Buttons -->
          <div v-if="template.buttons?.length" class="flex flex-col gap-1">
            <div
              v-for="btn in template.buttons"
              :key="btn.id"
              class="flex items-center gap-1 text-xs"
              :class="
                btn.type === 'template'
                  ? 'text-n-blue-11 cursor-pointer hover:underline'
                  : 'text-n-slate-10'
              "
              @click.stop="
                btn.type === 'template' && scrollToTemplate(btn.templateId)
              "
            >
              <span class="i-lucide-arrow-right size-3 flex-shrink-0" />
              <span class="truncate">
                {{
                  btn.type === 'template'
                    ? getTemplateName(btn.templateId)
                    : btn.url
                }}
              </span>
              <span class="ml-auto font-medium">{{ btn.label }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Preview panel (on hover) -->
    <div
      v-if="hoveredTemplate"
      class="w-72 flex-shrink-0 border-l border-n-weak p-4 overflow-y-auto"
    >
      <NotificationTemplatePreview
        :message-text="hoveredTemplate.messageText"
        :attachments="hoveredTemplate.attachments ?? []"
        :buttons="hoveredTemplate.buttons ?? []"
      />
    </div>

    <!-- Empty state hint -->
    <p v-if="!hoveredTemplate" class="hidden">
      {{ t('NOTIFICATION_TEMPLATES.PREVIEW.PLACEHOLDER') }}
    </p>
  </div>
</template>
