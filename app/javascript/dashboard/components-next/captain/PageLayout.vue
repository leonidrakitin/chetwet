<script setup>
import { ref, computed } from 'vue';
import { OnClickOutside } from '@vueuse/components';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store.js';
import { usePolicy } from 'dashboard/composables/usePolicy';
import Button from 'dashboard/components-next/button/Button.vue';
import BackButton from 'dashboard/components/widgets/BackButton.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Policy from 'dashboard/components/policy.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import AssistantSwitcher from 'dashboard/components-next/captain/pageComponents/switcher/AssistantSwitcher.vue';
import CreateAssistantDialog from 'dashboard/components-next/captain/pageComponents/assistant/CreateAssistantDialog.vue';

const props = defineProps({
  currentPage: {
    type: Number,
    default: 1,
  },
  totalCount: {
    type: Number,
    default: 100,
  },
  itemsPerPage: {
    type: Number,
    default: 25,
  },
  headerTitle: {
    type: String,
    default: '',
  },
  backUrl: {
    type: [String, Object],
    default: '',
  },
  buttonPolicy: {
    type: Array,
    default: () => [],
  },
  buttonLabel: {
    type: String,
    default: '',
  },
  featureFlag: {
    type: String,
    default: '',
  },
  isFetching: {
    type: Boolean,
    default: false,
  },
  showKnowMore: {
    type: Boolean,
    default: true,
  },
  isEmpty: {
    type: Boolean,
    default: false,
  },
  showPaginationFooter: {
    type: Boolean,
    default: true,
  },
  showAssistantSwitcher: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['click', 'close', 'update:currentPage']);

const { t } = useI18n();

const route = useRoute();
const router = useRouter();
const { shouldShowPaywall } = usePolicy();

const showAssistantSwitcherDropdown = ref(false);
const createAssistantDialogRef = ref(null);

const assistants = useMapGetter('captainAssistants/getRecords');
const uiFlags = useMapGetter('captainAssistants/getUIFlags');

const currentAssistantId = computed(() => route.params.assistantId);
const isFetchingAssistants = computed(() => uiFlags.value?.fetchingList);

const activeAssistantName = computed(() => {
  return (
    assistants.value?.find(
      assistant => assistant.id === Number(currentAssistantId.value)
    )?.name || t('CAPTAIN.ASSISTANT_SWITCHER.NEW_ASSISTANT')
  );
});

const showPaywall = computed(() => {
  return shouldShowPaywall(props.featureFlag);
});

const showLeftPanel = computed(
  () => props.showAssistantSwitcher && !showPaywall.value
);

const isAssistantActive = assistant =>
  assistant.id === Number(currentAssistantId.value);

const handleAssistantChange = async assistant => {
  if (isAssistantActive(assistant)) return;
  await router.push({
    name: route.name,
    params: {
      accountId: route.params.accountId,
      assistantId: assistant.id,
    },
  });
};

const handleButtonClick = () => {
  emit('click');
};

const handlePageChange = event => {
  emit('update:currentPage', event);
};

const toggleAssistantSwitcher = () => {
  showAssistantSwitcherDropdown.value = !showAssistantSwitcherDropdown.value;
};

const handleCreateAssistant = () => {
  showAssistantSwitcherDropdown.value = false;
  createAssistantDialogRef.value.dialogRef.open();
};
</script>

<template>
  <section class="flex w-full h-full overflow-hidden bg-n-surface-1">
    <!-- Left assistant panel — desktop only -->
    <aside
      v-if="showLeftPanel"
      class="hidden lg:flex flex-col w-52 border-r border-n-weak bg-n-solid-1 flex-shrink-0 overflow-hidden"
    >
      <div
        class="flex items-center justify-between px-3 py-3 border-b border-n-weak"
      >
        <span
          class="text-xs font-semibold text-n-slate-9 uppercase tracking-wider"
        >
          {{ t('CAPTAIN.ASSISTANT_SWITCHER.ASSISTANTS') }}
        </span>
        <Policy :permissions="['administrator']">
          <Button
            icon="i-lucide-plus"
            size="xs"
            variant="ghost"
            color="slate"
            :title="t('CAPTAIN.ASSISTANT_SWITCHER.NEW_ASSISTANT')"
            @click="handleCreateAssistant"
          />
        </Policy>
      </div>
      <div class="flex-1 overflow-y-auto py-1">
        <div v-if="isFetchingAssistants" class="flex justify-center py-6">
          <Spinner />
        </div>
        <template v-else>
          <button
            v-for="assistant in assistants"
            :key="assistant.id"
            class="w-[calc(100%-0.5rem)] flex items-center gap-2 px-3 py-2 text-left transition-colors rounded-lg mx-1 my-0.5"
            :class="
              isAssistantActive(assistant)
                ? 'bg-n-slate-3 text-n-slate-12'
                : 'text-n-slate-11 hover:bg-n-slate-2 hover:text-n-slate-12'
            "
            @click="handleAssistantChange(assistant)"
          >
            <Avatar
              :name="assistant.name"
              :size="20"
              icon-name="i-lucide-bot"
              rounded-full
              class="flex-shrink-0"
            />
            <span class="text-sm truncate font-medium">{{
              assistant.name
            }}</span>
          </button>
          <div
            v-if="assistants.length === 0"
            class="px-3 py-4 text-xs text-n-slate-9 text-center"
          >
            {{ t('CAPTAIN.ASSISTANT_SWITCHER.EMPTY_LIST') }}
          </div>
        </template>
      </div>
    </aside>

    <!-- Main content area -->
    <div class="flex flex-col flex-1 min-w-0">
      <header class="sticky top-0 z-10 px-6">
        <div class="w-full max-w-5xl mx-auto">
          <div
            class="flex items-start lg:items-center justify-between w-full py-6 lg:py-0 lg:h-20 gap-4 lg:gap-2 flex-col lg:flex-row"
          >
            <div class="flex gap-3 items-center">
              <BackButton v-if="backUrl" :back-url="backUrl" />
              <!-- Mobile: assistant name + dropdown -->
              <div
                v-if="showAssistantSwitcher && !showPaywall"
                class="flex items-center gap-2 lg:hidden"
              >
                <span
                  v-if="!isFetchingAssistants"
                  class="text-xl font-medium truncate text-n-slate-12"
                >
                  {{ activeAssistantName }}
                </span>
                <div class="relative group">
                  <OnClickOutside
                    @trigger="showAssistantSwitcherDropdown = false"
                  >
                    <Button
                      icon="i-lucide-chevron-down"
                      :variant="
                        showAssistantSwitcherDropdown ? 'faded' : 'ghost'
                      "
                      color="slate"
                      size="xs"
                      :disabled="isFetchingAssistants"
                      :is-loading="isFetchingAssistants"
                      class="rounded-md group-hover:bg-n-slate-3 hover:bg-n-slate-3 [&>span]:size-4"
                      @click="toggleAssistantSwitcher"
                    />

                    <AssistantSwitcher
                      v-if="showAssistantSwitcherDropdown"
                      class="absolute ltr:left-0 rtl:right-0 top-9"
                      @close="showAssistantSwitcherDropdown = false"
                      @create-assistant="handleCreateAssistant"
                    />
                  </OnClickOutside>
                </div>
              </div>
              <div class="flex items-center gap-4">
                <div
                  v-if="showAssistantSwitcher && !showPaywall && headerTitle"
                  class="w-0.5 h-4 rounded-2xl bg-n-weak lg:hidden"
                />
                <span
                  v-if="headerTitle"
                  class="text-xl font-medium text-n-slate-12"
                >
                  {{ headerTitle }}
                </span>
                <div
                  v-if="!isEmpty && showKnowMore"
                  class="flex items-center gap-2"
                >
                  <div class="w-0.5 h-4 rounded-2xl bg-n-weak" />
                  <slot name="knowMore" />
                </div>
              </div>
            </div>

            <div class="flex gap-2">
              <slot name="search" />
              <div
                v-if="!showPaywall && buttonLabel"
                v-on-clickaway="() => emit('close')"
                class="relative group/captain-button"
              >
                <Policy :permissions="buttonPolicy">
                  <Button
                    :label="buttonLabel"
                    icon="i-lucide-plus"
                    size="sm"
                    color="black"
                    class="group-hover/captain-button:brightness-110"
                    @click="handleButtonClick"
                  />
                </Policy>
                <slot name="action" />
              </div>
            </div>
          </div>
          <slot name="subHeader" />
        </div>
      </header>
      <main class="flex-1 px-6 overflow-y-auto">
        <div class="w-full max-w-5xl h-full mx-auto py-4">
          <slot v-if="!showPaywall" name="controls" />
          <div
            v-if="isFetching"
            class="flex items-center justify-center py-10 text-n-slate-11"
          >
            <Spinner />
          </div>
          <div v-else-if="showPaywall">
            <slot name="paywall" />
          </div>
          <div v-else-if="isEmpty">
            <slot name="emptyState" />
          </div>
          <slot v-else name="body" />
          <slot />
        </div>
      </main>
      <footer v-if="showPaginationFooter" class="sticky bottom-0 z-10">
        <PaginationFooter
          :current-page="currentPage"
          :total-items="totalCount"
          :items-per-page="itemsPerPage"
          class="max-w-[67rem]"
          @update:current-page="handlePageChange"
        />
      </footer>
    </div>

    <CreateAssistantDialog ref="createAssistantDialogRef" type="create" />
  </section>
</template>
