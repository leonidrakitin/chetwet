<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert, useTrack } from 'dashboard/composables';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { COPILOT_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';

const props = defineProps({
  show: { type: Boolean, default: false },
  currentChat: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['cancel']);

const api = () => window.axios;

const { t } = useI18n();

const outgoingMessages = ref([]);
const events = ref([]);
const selectedMessageId = ref(null);
const expandedEventIds = ref(new Set());
const isLoading = ref(false);
const hasLoaded = ref(false);

const localShow = computed({
  get: () => props.show,
  set: value => emit('cancel', value),
});

const DECISION_TYPES = [
  'decision_evaluated',
  'decision_selected',
  'decision_rejected',
  'decision_deferred',
  'escalation_decision',
];

const sections = [
  {
    key: 'prompt',
    labelKey: 'CAPTAIN.TRACE.SECTIONS.PROMPT',
    types: ['run_started', 'llm_request', 'prompt_snapshot', 'llm_response'],
  },
  {
    key: 'decisions',
    labelKey: 'CAPTAIN.TRACE.SECTIONS.DECISIONS',
    types: DECISION_TYPES,
  },
  {
    key: 'tools',
    labelKey: 'CAPTAIN.TRACE.SECTIONS.TOOLS',
    types: ['tool_start', 'tool_complete'],
  },
  {
    key: 'knowledge',
    labelKey: 'CAPTAIN.TRACE.SECTIONS.KNOWLEDGE',
    types: ['knowledge_hit'],
  },
  {
    key: 'policy',
    labelKey: 'CAPTAIN.TRACE.SECTIONS.POLICY',
    types: ['policy_check', 'citation_check', 'escalation'],
  },
  {
    key: 'outcome',
    labelKey: 'CAPTAIN.TRACE.SECTIONS.OUTCOME',
    types: [
      'agent_handoff',
      'handoff',
      'outgoing_message',
      'error',
      'run_completed',
    ],
  },
];

const groupedEvents = computed(() => {
  const grouped = {};
  sections.forEach(s => {
    grouped[s.key] = [];
  });
  events.value.forEach(event => {
    const section = sections.find(s => s.types.includes(event.event_type));
    const key = section ? section.key : 'outcome';
    grouped[key].push(event);
  });
  return grouped;
});

const loadData = async () => {
  if (!props.currentChat?.id) return;

  hasLoaded.value = true;
  isLoading.value = true;
  try {
    const url = `/api/v1/accounts/${props.currentChat.account_id}/conversations/${props.currentChat.id}/captain_trace_events`;
    const config = selectedMessageId.value
      ? { params: { message_id: selectedMessageId.value } }
      : {};
    const response = await api().get(url, config);
    outgoingMessages.value = response.data.outgoing_messages || [];
    events.value = response.data.events || [];
    useTrack(COPILOT_EVENTS.DEBUG_LOGS_OPENED);
  } catch (e) {
    useAlert(t('CAPTAIN.TRACE.ERROR_LOADING'));
  } finally {
    isLoading.value = false;
  }
};

watch(
  () => props.show,
  value => {
    if (value && !hasLoaded.value) loadData();
  },
  { immediate: true }
);

const selectMessage = id => {
  selectedMessageId.value = id;
  loadData();
};

const toggleEventExpanded = id => {
  const next = new Set(expandedEventIds.value);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  expandedEventIds.value = next;
};

const formatDate = iso => (iso ? new Date(iso).toLocaleString() : '');

const eventSummary = event => {
  const p = event.payload || {};
  if (event.event_type === 'tool_start' || event.event_type === 'tool_complete')
    return p.tool;
  if (event.event_type === 'outgoing_message') return p.content;
  if (event.event_type === 'handoff' || event.event_type === 'agent_handoff')
    return p.reason || p.reasoning || '';
  if (event.event_type === 'error')
    return `${p.class || ''}: ${p.message || ''}`;
  if (DECISION_TYPES.includes(event.event_type))
    return `${p.decision_domain || ''}/${p.decision_name || ''}`;
  if (event.event_type === 'knowledge_hit') return p.source || '';
  if (event.event_type === 'prompt_snapshot')
    return `${p.agent || ''} · ${p.message_count || 0} msg`;
  return '';
};

const isDecisionEvent = event => DECISION_TYPES.includes(event.event_type);
const isPromptSnapshotEvent = event => event.event_type === 'prompt_snapshot';

const formatDelay = seconds => {
  if (seconds === undefined || seconds === null || seconds === '') return '';
  const value = Number(seconds);
  if (!Number.isFinite(value) || value <= 0) return '';
  if (value < 60) return `${value}s`;
  if (value < 3600) return `${Math.round(value / 60)}m`;
  if (value < 86400) return `${Math.round(value / 3600)}h`;
  return `${Math.round(value / 86400)}d`;
};

const formatScheduledFor = iso => (iso ? new Date(iso).toLocaleString() : '');

const decisionBadgeClass = event => {
  const selected = event.payload?.selected;
  if (selected === true)
    return 'bg-emerald-100 text-emerald-800 border-emerald-200';
  if (selected === false) return 'bg-rose-100 text-rose-800 border-rose-200';
  if (event.event_type === 'decision_deferred')
    return 'bg-amber-100 text-amber-800 border-amber-200';
  return 'bg-slate-100 text-slate-700 border-slate-200';
};

const decisionStatusLabel = event => {
  const selected = event.payload?.selected;
  if (selected === true) return t('CAPTAIN.TRACE.DECISIONS.SELECTED');
  if (selected === false) return t('CAPTAIN.TRACE.DECISIONS.REJECTED');
  if (event.event_type === 'decision_deferred')
    return t('CAPTAIN.TRACE.DECISIONS.DEFERRED');
  return t('CAPTAIN.TRACE.DECISIONS.EVALUATED');
};
</script>

<template>
  <woot-modal
    v-model:show="localShow"
    size="modal-big"
    @close="() => emit('cancel', false)"
  >
    <div class="flex flex-col h-[70vh] overflow-hidden bg-white">
      <div
        class="flex items-center justify-between px-6 py-4 bg-purple-50 border-b border-purple-200"
      >
        <div class="flex items-center gap-3">
          <Icon icon="i-lucide-terminal" class="w-5 h-5 text-purple-700" />
          <h3 class="text-base font-semibold text-purple-900">
            {{ t('CAPTAIN.TRACE.TITLE') }}
          </h3>
        </div>
        <Icon
          icon="i-lucide-x"
          class="w-5 h-5 text-purple-600 cursor-pointer"
          @click="() => emit('cancel', false)"
        />
      </div>

      <div class="flex-1 flex min-h-0">
        <aside
          class="w-64 border-r border-slate-200 overflow-y-auto bg-slate-50"
        >
          <div class="px-4 py-3 text-xs uppercase text-slate-500 tracking-wide">
            {{ t('CAPTAIN.TRACE.OUTGOING_MESSAGES') }}
          </div>
          <button
            type="button"
            class="w-full text-left px-4 py-2 text-sm hover:bg-purple-50"
            :class="{ 'bg-purple-100': !selectedMessageId }"
            @click="selectMessage(null)"
          >
            {{ t('CAPTAIN.TRACE.ALL_EVENTS') }}
          </button>
          <button
            v-for="msg in outgoingMessages"
            :key="msg.id"
            type="button"
            class="w-full text-left px-4 py-2 text-sm border-t border-slate-200 hover:bg-purple-50"
            :class="{ 'bg-purple-100': selectedMessageId === msg.id }"
            @click="selectMessage(msg.id)"
          >
            <div class="text-xs text-slate-500">
              {{ formatDate(msg.created_at) }}
            </div>
            <div class="truncate font-medium text-slate-800">
              {{ msg.content || '—' }}
            </div>
            <div v-if="msg.agent_name" class="text-xs text-cyan-700 mt-1">
              {{ msg.agent_name }}
            </div>
          </button>
          <div
            v-if="!outgoingMessages.length"
            class="px-4 py-2 text-xs text-slate-400"
          >
            {{ t('CAPTAIN.TRACE.NO_OUTGOING_MESSAGES') }}
          </div>
        </aside>

        <section class="flex-1 overflow-y-auto p-6">
          <div v-if="isLoading" class="flex items-center justify-center py-12">
            <Icon
              icon="i-lucide-loader-2"
              class="w-6 h-6 text-purple-700 animate-spin"
            />
          </div>
          <div
            v-else-if="!events.length"
            class="text-center text-slate-500 pt-8"
          >
            {{ t('CAPTAIN.TRACE.NO_EVENTS') }}
          </div>
          <div v-else class="space-y-6">
            <div
              v-for="section in sections"
              :key="section.key"
              class="space-y-2"
            >
              <h4
                class="text-xs font-semibold uppercase tracking-wide text-slate-600"
              >
                {{ t(section.labelKey) }}
              </h4>
              <div
                v-if="!groupedEvents[section.key].length"
                class="text-xs text-slate-400"
              >
                —
              </div>
              <div
                v-for="event in groupedEvents[section.key]"
                :key="event.id"
                class="border border-slate-200 rounded-md"
              >
                <button
                  type="button"
                  class="w-full flex items-center justify-between px-3 py-2 text-left hover:bg-slate-50"
                  @click="toggleEventExpanded(event.id)"
                >
                  <div class="flex items-center gap-2 min-w-0">
                    <span
                      class="text-[10px] font-mono font-bold text-slate-500"
                    >
                      #{{ event.sequence }}
                    </span>
                    <span
                      v-if="isDecisionEvent(event)"
                      class="text-[10px] font-semibold uppercase border rounded px-1.5 py-0.5"
                      :class="decisionBadgeClass(event)"
                    >
                      {{ decisionStatusLabel(event) }}
                    </span>
                    <span class="text-xs font-medium text-purple-800">
                      {{ event.event_type }}
                    </span>
                    <span class="text-xs text-slate-500 truncate">
                      {{ eventSummary(event) }}
                    </span>
                  </div>
                  <span class="text-[10px] text-slate-400 ml-2">
                    {{ formatDate(event.created_at) }}
                  </span>
                </button>
                <div
                  v-if="isPromptSnapshotEvent(event)"
                  class="px-3 py-2 bg-slate-50 border-t border-slate-200 space-y-2"
                >
                  <div
                    v-if="event.payload?.system_prompt"
                    class="text-xs text-slate-700"
                  >
                    <div class="font-semibold text-slate-600 mb-1">
                      {{ t('CAPTAIN.TRACE.PROMPT.SYSTEM') }}
                    </div>
                    <pre
                      class="whitespace-pre-wrap break-words bg-white border border-slate-200 rounded p-2 text-[11px]"
                      >{{ event.payload.system_prompt }}</pre
                    >
                  </div>
                  <div
                    v-if="event.payload?.messages?.length"
                    class="text-xs text-slate-700"
                  >
                    <div class="font-semibold text-slate-600 mb-1">
                      {{ t('CAPTAIN.TRACE.PROMPT.MESSAGES') }}
                      ({{ event.payload.message_count }})
                    </div>
                    <div class="space-y-1">
                      <div
                        v-for="(msg, idx) in event.payload.messages"
                        :key="idx"
                        class="bg-white border border-slate-200 rounded p-2"
                      >
                        <span
                          class="text-[10px] font-mono uppercase text-purple-700 mr-2"
                        >
                          {{ msg.role }}
                        </span>
                        <span
                          class="whitespace-pre-wrap break-words text-[11px]"
                        >
                          {{ msg.content }}
                        </span>
                      </div>
                    </div>
                  </div>
                  <div
                    v-if="event.payload?.tool_instructions?.length"
                    class="text-xs text-slate-700"
                  >
                    <div class="font-semibold text-slate-600 mb-1">
                      {{ t('CAPTAIN.TRACE.PROMPT.TOOLS') }}
                    </div>
                    <ul class="space-y-0.5 list-disc pl-4">
                      <li
                        v-for="(tool, idx) in event.payload.tool_instructions"
                        :key="idx"
                        class="text-[11px]"
                      >
                        <span class="font-mono text-slate-800">
                          {{ tool.name }}
                        </span>
                        <span v-if="tool.description" class="text-slate-500">
                          — {{ tool.description }}
                        </span>
                      </li>
                    </ul>
                  </div>
                </div>
                <div
                  v-if="isDecisionEvent(event)"
                  class="px-3 py-2 bg-slate-50 border-t border-slate-200 space-y-1"
                >
                  <div
                    v-if="event.payload?.reasoning_summary"
                    class="text-xs text-slate-700"
                  >
                    <span class="font-semibold text-slate-600">
                      {{ t('CAPTAIN.TRACE.DECISIONS.WHY') }}:
                    </span>
                    {{ event.payload.reasoning_summary }}
                  </div>
                  <div
                    v-if="
                      event.payload?.template_name || event.payload?.template_id
                    "
                    class="text-xs text-slate-700"
                  >
                    <span class="font-semibold text-slate-600">
                      {{ t('CAPTAIN.TRACE.DECISIONS.TEMPLATE') }}:
                    </span>
                    {{
                      event.payload.template_name || event.payload.template_id
                    }}
                    <span
                      v-if="
                        event.payload.template_id && event.payload.template_name
                      "
                      class="text-slate-400"
                    >
                      (#{{ event.payload.template_id }})
                    </span>
                  </div>
                  <div
                    v-if="
                      event.payload?.scheduled_for ||
                      event.payload?.delay_seconds
                    "
                    class="text-xs text-slate-700"
                  >
                    <span class="font-semibold text-slate-600">
                      {{ t('CAPTAIN.TRACE.DECISIONS.SCHEDULED_FOR') }}:
                    </span>
                    {{ formatScheduledFor(event.payload.scheduled_for) }}
                    <span
                      v-if="event.payload.delay_seconds"
                      class="text-slate-500"
                    >
                      ({{ t('CAPTAIN.TRACE.DECISIONS.IN') }}
                      {{ formatDelay(event.payload.delay_seconds) }})
                    </span>
                  </div>
                  <div
                    v-if="event.payload?.correlation_id"
                    class="text-[10px] text-slate-400 font-mono"
                  >
                    {{ t('CAPTAIN.TRACE.DECISIONS.CORRELATION') }}:
                    {{ event.payload.correlation_id }}
                  </div>
                </div>
                <pre
                  v-if="expandedEventIds.has(event.id)"
                  class="text-xs bg-slate-50 border-t border-slate-200 p-3 whitespace-pre-wrap break-all"
                  >{{ JSON.stringify(event.payload, null, 2) }}</pre
                >
              </div>
            </div>
          </div>
        </section>
      </div>

      <div
        class="flex justify-end px-6 py-3 bg-slate-50 border-t border-slate-200"
      >
        <Button
          :label="t('CAPTAIN.TRACE.CLOSE')"
          @click="() => emit('cancel', false)"
        />
      </div>
    </div>
  </woot-modal>
</template>
