<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import InsightsAPI from 'dashboard/api/captain/insights';

const { t } = useI18n();
const route = useRoute();

const assistantId = computed(() => Number(route.params.assistantId));
const days = ref(30);
const isFetching = ref(false);
const data = ref(null);
const error = ref(null);

const fetchInsights = async () => {
  isFetching.value = true;
  error.value = null;
  try {
    const { data: payload } = await InsightsAPI.fetch({
      days: days.value,
      assistantId: assistantId.value,
    });
    data.value = payload;
  } catch (err) {
    error.value = err?.response?.data?.error || err.message;
  } finally {
    isFetching.value = false;
  }
};

onMounted(fetchInsights);
watch([assistantId, days], fetchInsights);

const routingTotal = computed(() => {
  const r = data.value?.routing || {};
  return Object.values(r).reduce((acc, v) => acc + (v || 0), 0);
});

const confidenceTotal = computed(() => {
  const c = data.value?.confidence_buckets || {};
  return Object.values(c).reduce((acc, v) => acc + (v || 0), 0);
});

const routingPercent = key => {
  const total = routingTotal.value;
  if (!total) return 0;
  return Math.round(((data.value?.routing?.[key] || 0) / total) * 100);
};

const confidencePercent = key => {
  const total = confidenceTotal.value;
  if (!total) return 0;
  return Math.round(
    ((data.value?.confidence_buckets?.[key] || 0) / total) * 100
  );
};

const routingLabels = {
  direct: t('CAPTAIN.INSIGHTS.ROUTING.DIRECT'),
  faq: t('CAPTAIN.INSIGHTS.ROUTING.FAQ'),
  scenario_handoff: t('CAPTAIN.INSIGHTS.ROUTING.SCENARIO'),
  human: t('CAPTAIN.INSIGHTS.ROUTING.HUMAN'),
};

const confidenceLabels = {
  low: t('CAPTAIN.INSIGHTS.CONFIDENCE.LOW'),
  medium: t('CAPTAIN.INSIGHTS.CONFIDENCE.MEDIUM'),
  high: t('CAPTAIN.INSIGHTS.CONFIDENCE.HIGH'),
  very_high: t('CAPTAIN.INSIGHTS.CONFIDENCE.VERY_HIGH'),
};

const approvalLabels = {
  pending: t('CAPTAIN.INSIGHTS.APPROVALS.PENDING'),
  resolved: t('CAPTAIN.INSIGHTS.APPROVALS.RESOLVED'),
  expired: t('CAPTAIN.INSIGHTS.APPROVALS.EXPIRED'),
};
</script>

<template>
  <PageLayout
    :header-title="t('CAPTAIN.INSIGHTS.HEADER')"
    :show-pagination-footer="false"
    :is-fetching="isFetching"
  >
    <template #subHeader>
      <div class="flex items-center gap-3 pb-4">
        <label class="text-sm text-n-slate-11" for="days-range">
          {{ t('CAPTAIN.INSIGHTS.RANGE_LABEL') }}
        </label>
        <select
          id="days-range"
          v-model.number="days"
          class="bg-n-alpha-1 border border-n-strong rounded-md text-sm px-2 py-1"
        >
          <option :value="7">{{ t('CAPTAIN.INSIGHTS.RANGES.WEEK') }}</option>
          <option :value="30">{{ t('CAPTAIN.INSIGHTS.RANGES.MONTH') }}</option>
          <option :value="90">
            {{ t('CAPTAIN.INSIGHTS.RANGES.QUARTER') }}
          </option>
        </select>
      </div>
    </template>

    <template #body>
      <div v-if="error" class="p-4 rounded-md bg-n-ruby-2 text-n-ruby-11">
        {{ error }}
      </div>
      <div v-else-if="!data" class="flex items-center justify-center py-10">
        <Spinner />
      </div>
      <div v-else class="flex flex-col gap-6 pb-8">
        <!-- Summary cards -->
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <div class="p-4 rounded-md bg-n-alpha-1 border border-n-strong">
            <div class="text-xs text-n-slate-11">
              {{ t('CAPTAIN.INSIGHTS.TOTALS.CONVERSATIONS') }}
            </div>
            <div class="text-2xl font-semibold text-n-slate-12">
              {{ data.conversations_with_captain }}
            </div>
          </div>
          <div class="p-4 rounded-md bg-n-alpha-1 border border-n-strong">
            <div class="text-xs text-n-slate-11">
              {{ t('CAPTAIN.INSIGHTS.TOTALS.HANDOFF_RATE') }}
            </div>
            <div class="text-2xl font-semibold text-n-slate-12">
              {{ Math.round((data.escalations?.handoff_rate || 0) * 100) }}%
            </div>
          </div>
          <div class="p-4 rounded-md bg-n-alpha-1 border border-n-strong">
            <div class="text-xs text-n-slate-11">
              {{ t('CAPTAIN.INSIGHTS.TOTALS.PENDING_HUMAN') }}
            </div>
            <div class="text-2xl font-semibold text-n-slate-12">
              {{ data.escalations?.pending_human_interaction || 0 }}
            </div>
          </div>
        </div>

        <!-- Routing -->
        <section class="rounded-md border border-n-strong bg-n-alpha-1 p-4">
          <h2 class="text-sm font-medium text-n-slate-12 mb-3">
            {{ t('CAPTAIN.INSIGHTS.ROUTING.HEADER') }}
          </h2>
          <div class="flex flex-col gap-2">
            <div
              v-for="key in ['direct', 'faq', 'scenario_handoff', 'human']"
              :key="key"
              class="flex items-center gap-3 text-sm"
            >
              <div class="w-32 text-n-slate-11">{{ routingLabels[key] }}</div>
              <div class="flex-1 h-2 rounded bg-n-alpha-2 overflow-hidden">
                <div
                  class="h-full bg-n-brand"
                  :style="{ width: routingPercent(key) + '%' }"
                />
              </div>
              <div class="w-16 text-right text-n-slate-12">
                {{ data.routing?.[key] || 0 }}
                <span class="text-n-slate-10">
                  ({{ routingPercent(key) }}%)
                </span>
              </div>
            </div>
          </div>
        </section>

        <!-- Confidence -->
        <section class="rounded-md border border-n-strong bg-n-alpha-1 p-4">
          <h2 class="text-sm font-medium text-n-slate-12 mb-3">
            {{ t('CAPTAIN.INSIGHTS.CONFIDENCE.HEADER') }}
          </h2>
          <div class="flex flex-col gap-2">
            <div
              v-for="key in ['low', 'medium', 'high', 'very_high']"
              :key="key"
              class="flex items-center gap-3 text-sm"
            >
              <div class="w-32 text-n-slate-11">
                {{ confidenceLabels[key] }}
              </div>
              <div class="flex-1 h-2 rounded bg-n-alpha-2 overflow-hidden">
                <div
                  class="h-full bg-n-teal-9"
                  :style="{ width: confidencePercent(key) + '%' }"
                />
              </div>
              <div class="w-16 text-right text-n-slate-12">
                {{ data.confidence_buckets?.[key] || 0 }}
                <span class="text-n-slate-10">
                  ({{ confidencePercent(key) }}%)
                </span>
              </div>
            </div>
          </div>
        </section>

        <!-- Approvals + Top assistants -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <section class="rounded-md border border-n-strong bg-n-alpha-1 p-4">
            <h2 class="text-sm font-medium text-n-slate-12 mb-3">
              {{ t('CAPTAIN.INSIGHTS.APPROVALS.HEADER') }}
            </h2>
            <dl class="flex flex-col gap-2 text-sm">
              <div
                v-for="key in ['pending', 'resolved', 'expired']"
                :key="key"
                class="flex justify-between"
              >
                <dt class="text-n-slate-11">{{ approvalLabels[key] }}</dt>
                <dd class="text-n-slate-12">
                  {{ data.approvals?.[key] || 0 }}
                </dd>
              </div>
            </dl>
          </section>

          <section class="rounded-md border border-n-strong bg-n-alpha-1 p-4">
            <h2 class="text-sm font-medium text-n-slate-12 mb-3">
              {{ t('CAPTAIN.INSIGHTS.TOP_ASSISTANTS.HEADER') }}
            </h2>
            <ul
              v-if="data.top_assistants?.length"
              class="flex flex-col gap-2 text-sm"
            >
              <li
                v-for="row in data.top_assistants"
                :key="row.id"
                class="flex justify-between"
              >
                <span class="text-n-slate-11">{{ row.name }}</span>
                <span class="text-n-slate-12">{{ row.conversations }}</span>
              </li>
            </ul>
            <p v-else class="text-sm text-n-slate-11">
              {{ t('CAPTAIN.INSIGHTS.TOP_ASSISTANTS.EMPTY') }}
            </p>
          </section>
        </div>
      </div>
    </template>
  </PageLayout>
</template>
