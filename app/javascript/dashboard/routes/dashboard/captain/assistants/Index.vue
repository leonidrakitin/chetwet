<script setup>
import { computed, ref, nextTick } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import CreateFromTemplateDialog from 'dashboard/components-next/captain/pageComponents/assistant/CreateFromTemplateDialog.vue';
import AssistantPageEmptyState from 'dashboard/components-next/captain/pageComponents/emptyStates/AssistantPageEmptyState.vue';
import FeatureSpotlightPopover from 'dashboard/components-next/feature-spotlight/FeatureSpotlightPopover.vue';

const { isOnChatwootCloud } = useAccount();

const uiFlags = useMapGetter('captainAssistants/getUIFlags');
const isFetching = computed(() => uiFlags.value.fetchingList);

const createFromTemplateDialog = ref(null);

const handleCreate = () => {
  nextTick(() => createFromTemplateDialog.value.open());
};
</script>

<template>
  <PageLayout
    :header-title="$t('CAPTAIN.ASSISTANTS.HEADER')"
    :show-pagination-footer="false"
    :is-fetching="isFetching"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
    is-empty
    @click="handleCreate"
  >
    <template #knowMore>
      <FeatureSpotlightPopover
        :button-label="$t('CAPTAIN.HEADER_KNOW_MORE')"
        :title="$t('CAPTAIN.ASSISTANTS.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
        :note="$t('CAPTAIN.ASSISTANTS.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
        :hide-actions="!isOnChatwootCloud"
        fallback-thumbnail="/assets/images/dashboard/captain/assistant-popover-light.svg"
        fallback-thumbnail-dark="/assets/images/dashboard/captain/assistant-popover-dark.svg"
        learn-more-url="https://chwt.app/captain-assistant"
      />
    </template>
    <template #emptyState>
      <AssistantPageEmptyState @click="handleCreate" />
    </template>

    <template #paywall>
      <CaptainPaywall />
    </template>

    <CreateFromTemplateDialog ref="createFromTemplateDialog" />
  </PageLayout>
</template>
