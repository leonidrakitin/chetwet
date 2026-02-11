<script setup>
import { onMounted, computed, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SegmentStatistics from 'dashboard/components-next/Contacts/Segments/SegmentStatistics.vue';

const store = useStore();
const route = useRoute();
const { t } = useI18n();
const { accountScopedRoute } = useAccount();

const segmentId = computed(() => route.params.segmentId);

const segment = computed(() =>
  store.getters['contactSegments/getSegmentById'](segmentId.value)
);

const statistics = computed(() =>
  store.getters['contactSegments/getStatisticsBySegmentId'](segmentId.value)
);

const segmentUIFlags = useMapGetter('contactSegments/getUIFlags');
const isFetching = computed(() => segmentUIFlags.value.isFetching);

const fetchData = () => {
  store.dispatch('contactSegments/get');
  store.dispatch('contactSegments/getStatistics', segmentId.value);
};

const contactsRoute = computed(() => {
  return accountScopedRoute(
    'contacts_dashboard_segments_index',
    { segmentId: segmentId.value },
    { page: 1 }
  );
});

watch(segmentId, fetchData);

onMounted(fetchData);
</script>

<template>
  <div class="flex flex-col flex-1 h-full m-0 overflow-auto bg-n-surface-1">
    <div class="px-6 py-4">
      <!-- Header -->
      <div class="flex items-center gap-3 mb-6">
        <RouterLink
          :to="accountScopedRoute('contacts_segments_dashboard')"
          class="text-n-slate-11 hover:text-n-slate-12 no-underline"
        >
          <span class="i-lucide-arrow-left size-5" />
        </RouterLink>
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ segment?.name || t('SEGMENT_SHOW.LOADING') }}
        </h1>
        <span
          v-if="segment"
          class="px-2 py-0.5 text-xs rounded-full"
          :class="
            segment.active
              ? 'bg-n-teal-3 text-n-teal-11'
              : 'bg-n-slate-3 text-n-slate-11'
          "
        >
          {{ segment.active ? t('SEGMENTS_DASHBOARD.ACTIVE') : t('SEGMENTS_DASHBOARD.INACTIVE') }}
        </span>
      </div>

      <div
        v-if="isFetching && !segment"
        class="flex items-center justify-center py-10 text-n-slate-11"
      >
        <Spinner />
      </div>

      <template v-else-if="segment">
        <!-- Statistics -->
        <SegmentStatistics :statistics="statistics" class="mb-6" />

        <!-- Segment Parameters -->
        <section class="mb-6">
          <h2 class="mb-3 text-base font-medium text-n-slate-12">
            {{ t('SEGMENT_SHOW.PARAMETERS') }}
          </h2>
          <div
            v-if="segment.description"
            class="mb-2 text-sm text-n-slate-11"
          >
            {{ segment.description }}
          </div>
          <div class="p-3 rounded-lg border border-n-weak bg-n-background">
            <pre class="text-xs text-n-slate-11 whitespace-pre-wrap m-0">{{
              JSON.stringify(segment.query, null, 2)
            }}</pre>
          </div>
        </section>

        <!-- View Contacts Link -->
        <section>
          <RouterLink :to="contactsRoute" class="no-underline">
            <Button
              :label="t('SEGMENT_SHOW.VIEW_CONTACTS')"
              icon="i-lucide-users"
              color="primary"
            />
          </RouterLink>
        </section>
      </template>
    </div>
  </div>
</template>
