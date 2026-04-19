<script setup>
import { ref, computed, watch, onMounted, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Draggable from 'vuedraggable';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { getInboxIconByType } from 'dashboard/helper/inbox';

const { t } = useI18n();
const store = useStore();

const allInboxes = computed(() => store.getters['inboxes/getInboxes']);
const uiFlags = computed(
  () => store.getters['notificationTemplates/getUIFlags']
);
const inboxesUiFlags = computed(() => store.getters['inboxes/getUIFlags']);
const savedSettings = computed(
  () => store.getters['notificationTemplates/getCascadeSettings']
);

/** False until onMounted finishes dispatching — avoids empty-state flash before fetches start. */
const hasStartedCascadeBootstrap = ref(false);

const showCascadeLoading = computed(() => {
  if (!hasStartedCascadeBootstrap.value) return true;
  return uiFlags.value.isFetchingCascade || inboxesUiFlags.value.isFetching;
});

const marketingChain = ref([]);
const serviceChain = ref([]);

/** When true, do not replace local chains from store (avoids wiping edits when inboxes load/update). */
const chainsEditedLocally = ref(false);

const buildChain = (ids, inboxes) => {
  const byId = Object.fromEntries(inboxes.map(i => [i.id, i]));
  return ids.filter(id => byId[id]).map(id => byId[id]);
};

const hydrateChainsFromStore = () => {
  const inboxes = allInboxes.value;
  const settings = savedSettings.value;
  if (!inboxes.length) return;
  marketingChain.value = buildChain(settings.marketing || [], inboxes);
  serviceChain.value = buildChain(settings.service || [], inboxes);
};

watch(
  [savedSettings, allInboxes],
  () => {
    if (!allInboxes.value.length || chainsEditedLocally.value) return;
    hydrateChainsFromStore();
  },
  { immediate: true }
);

const availableForMarketing = computed(() => {
  const used = new Set(marketingChain.value.map(i => i.id));
  return allInboxes.value.filter(i => !used.has(i.id));
});

const availableForService = computed(() => {
  const used = new Set(serviceChain.value.map(i => i.id));
  return allInboxes.value.filter(i => !used.has(i.id));
});

const showMarketingPicker = ref(false);
const showServicePicker = ref(false);

const addToChain = (chain, inbox) => {
  chainsEditedLocally.value = true;
  chain.push(inbox);
};

const removeFromChain = (chain, index) => {
  chainsEditedLocally.value = true;
  chain.splice(index, 1);
};

const onReorderChains = () => {
  chainsEditedLocally.value = true;
};

const handleSave = async () => {
  try {
    await store.dispatch('notificationTemplates/saveCascadeSettings', {
      marketing: marketingChain.value.map(i => i.id),
      service: serviceChain.value.map(i => i.id),
    });
    chainsEditedLocally.value = false;
    await nextTick();
    hydrateChainsFromStore();
    useAlert(t('NOTIFICATION_TEMPLATES.CASCADE.SAVE_SUCCESS'));
  } catch {
    useAlert(t('NOTIFICATION_TEMPLATES.CASCADE.SAVE_ERROR'));
  }
};

const inboxIcon = inbox =>
  getInboxIconByType(inbox.channel_type, inbox.medium, 'outline');

onMounted(() => {
  if (!allInboxes.value.length) {
    store.dispatch('inboxes/get');
  }
  store.dispatch('notificationTemplates/fetchCascadeSettings');
  hasStartedCascadeBootstrap.value = true;
});
</script>

<template>
  <div class="max-w-6xl mx-auto py-6 px-4 md:px-0 flex flex-col gap-6">
    <!-- Page intro -->
    <div class="flex flex-col gap-1">
      <h2 class="text-base font-semibold text-n-slate-12">
        {{ t('NOTIFICATION_TEMPLATES.CASCADE.TITLE') }}
      </h2>
      <p class="text-sm text-n-slate-10">
        {{ t('NOTIFICATION_TEMPLATES.CASCADE.DESCRIPTION') }}
      </p>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start min-w-0">
      <!-- Marketing notifications card -->
      <div class="rounded-xl border border-n-weak bg-n-surface-1 min-w-0">
        <!-- Card header -->
        <div
          class="px-5 py-4 border-b border-n-weak rounded-t-xl bg-gradient-to-r from-violet-50/60 to-transparent dark:from-violet-950/20"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <div
                class="flex items-center justify-center size-8 rounded-lg bg-violet-100 dark:bg-violet-900/40 flex-shrink-0"
              >
                <span
                  class="i-lucide-megaphone size-4 text-violet-600 dark:text-violet-400"
                />
              </div>
              <div>
                <div class="flex items-center gap-2">
                  <h3 class="text-sm font-semibold text-n-slate-12">
                    {{ t('NOTIFICATION_TEMPLATES.CASCADE.MARKETING.TITLE') }}
                  </h3>
                  <span
                    class="inline-flex items-center px-1.5 py-0.5 rounded-md text-[10px] font-semibold uppercase tracking-wide bg-violet-100 dark:bg-violet-900/40 text-violet-700 dark:text-violet-300"
                  >
                    {{ t('NOTIFICATION_TEMPLATES.CASCADE.MARKETING.BADGE') }}
                  </span>
                </div>
                <p class="text-xs text-n-slate-9 mt-0.5">
                  {{
                    t('NOTIFICATION_TEMPLATES.CASCADE.MARKETING.DESCRIPTION')
                  }}
                </p>
              </div>
            </div>
          </div>

          <!-- Legal notice -->
          <div
            class="mt-3 flex items-start gap-2.5 rounded-lg bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800/50 px-3 py-2.5"
          >
            <span
              class="i-lucide-triangle-alert size-3.5 text-amber-600 dark:text-amber-400 mt-0.5 flex-shrink-0"
            />
            <div class="flex-1 min-w-0">
              <p
                class="text-xs text-amber-800 dark:text-amber-300 leading-relaxed"
              >
                {{ t('NOTIFICATION_TEMPLATES.CASCADE.MARKETING.LEGAL_NOTICE') }}
              </p>
              <button
                class="mt-1 text-xs font-medium text-amber-700 dark:text-amber-400 underline underline-offset-2 hover:text-amber-900 dark:hover:text-amber-200 transition-colors"
                @click.prevent
              >
                {{ t('NOTIFICATION_TEMPLATES.CASCADE.MARKETING.LEARN_MORE') }}
              </button>
            </div>
          </div>
        </div>

        <!-- Chain list -->
        <div class="px-5 py-4">
          <div
            v-if="showCascadeLoading"
            class="py-10 flex flex-col items-center justify-center gap-2 text-n-slate-9"
          >
            <Spinner :size="20" />
            <span class="sr-only">{{
              t('NOTIFICATION_TEMPLATES.CASCADE.LOADING')
            }}</span>
          </div>
          <div v-else-if="marketingChain.length === 0" class="py-6 text-center">
            <p class="text-sm text-n-slate-9">
              {{ t('NOTIFICATION_TEMPLATES.CASCADE.EMPTY_CHAIN') }}
            </p>
          </div>

          <Draggable
            v-else
            v-model="marketingChain"
            item-key="id"
            handle=".cascade-drag"
            ghost-class="opacity-40"
            animation="150"
            class="flex flex-col gap-2"
            @end="onReorderChains"
          >
            <template #item="{ element, index }">
              <div
                class="flex items-center gap-3 rounded-lg bg-n-alpha-1 border border-n-weak px-3 py-2.5 group"
              >
                <!-- Step number -->
                <div
                  class="flex items-center justify-center size-5 rounded-full bg-n-alpha-2 text-[11px] font-semibold text-n-slate-10 flex-shrink-0"
                >
                  {{ index + 1 }}
                </div>

                <!-- Drag handle -->
                <span
                  class="cascade-drag i-lucide-grip-vertical size-4 text-n-slate-8 hover:text-n-slate-11 cursor-grab flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity"
                />

                <!-- Channel icon -->
                <span
                  :class="inboxIcon(element)"
                  class="size-5 flex-shrink-0 text-n-slate-9"
                />

                <!-- Inbox name -->
                <span
                  class="flex-1 text-sm font-medium text-n-slate-12 truncate min-w-0"
                >
                  {{ element.name }}
                </span>

                <!-- Arrow (not last) -->
                <span
                  v-if="index < marketingChain.length - 1"
                  class="i-lucide-arrow-right size-3.5 text-n-slate-7 flex-shrink-0"
                />

                <!-- Remove -->
                <button
                  class="ml-auto flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity p-1 rounded hover:bg-n-alpha-2 text-n-slate-9 hover:text-ruby-10"
                  @click="removeFromChain(marketingChain, index)"
                >
                  <span class="i-lucide-x size-3.5" />
                </button>
              </div>
            </template>
          </Draggable>

          <!-- Add channel -->
          <div v-if="!showCascadeLoading" class="mt-3 relative">
            <Button
              variant="ghost"
              size="sm"
              icon="i-lucide-plus"
              :label="t('NOTIFICATION_TEMPLATES.CASCADE.ADD_CHANNEL')"
              :disabled="availableForMarketing.length === 0"
              @click="showMarketingPicker = !showMarketingPicker"
            />
            <div
              v-if="showMarketingPicker && availableForMarketing.length"
              class="absolute top-full left-0 mt-1 z-20 bg-n-solid-3 border border-n-weak rounded-lg shadow-lg py-1 min-w-52 max-h-60 overflow-y-auto"
            >
              <button
                v-for="inbox in availableForMarketing"
                :key="inbox.id"
                class="flex items-center gap-2.5 w-full px-3 py-2 hover:bg-n-alpha-1 text-sm text-n-slate-12 text-left"
                @click="
                  addToChain(marketingChain, inbox);
                  showMarketingPicker = false;
                "
              >
                <span
                  :class="inboxIcon(inbox)"
                  class="size-4 text-n-slate-9 flex-shrink-0"
                />
                {{ inbox.name }}
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Service notifications card -->
      <div class="rounded-xl border border-n-weak bg-n-surface-1 min-w-0">
        <!-- Card header -->
        <div
          class="px-5 py-4 border-b border-n-weak rounded-t-xl bg-gradient-to-r from-blue-50/60 to-transparent dark:from-blue-950/20"
        >
          <div class="flex items-center gap-2.5">
            <div
              class="flex items-center justify-center size-8 rounded-lg bg-blue-100 dark:bg-blue-900/40 flex-shrink-0"
            >
              <span
                class="i-lucide-bell size-4 text-blue-600 dark:text-blue-400"
              />
            </div>
            <div>
              <div class="flex items-center gap-2">
                <h3 class="text-sm font-semibold text-n-slate-12">
                  {{ t('NOTIFICATION_TEMPLATES.CASCADE.SERVICE.TITLE') }}
                </h3>
                <span
                  class="inline-flex items-center px-1.5 py-0.5 rounded-md text-[10px] font-semibold uppercase tracking-wide bg-blue-100 dark:bg-blue-900/40 text-blue-700 dark:text-blue-300"
                >
                  {{ t('NOTIFICATION_TEMPLATES.CASCADE.SERVICE.BADGE') }}
                </span>
              </div>
              <p class="text-xs text-n-slate-9 mt-0.5">
                {{ t('NOTIFICATION_TEMPLATES.CASCADE.SERVICE.DESCRIPTION') }}
              </p>
            </div>
          </div>
        </div>

        <!-- Chain list -->
        <div class="px-5 py-4">
          <div
            v-if="showCascadeLoading"
            class="py-10 flex flex-col items-center justify-center gap-2 text-n-slate-9"
          >
            <Spinner :size="20" />
            <span class="sr-only">{{
              t('NOTIFICATION_TEMPLATES.CASCADE.LOADING')
            }}</span>
          </div>
          <div v-else-if="serviceChain.length === 0" class="py-6 text-center">
            <p class="text-sm text-n-slate-9">
              {{ t('NOTIFICATION_TEMPLATES.CASCADE.EMPTY_CHAIN') }}
            </p>
          </div>

          <Draggable
            v-else
            v-model="serviceChain"
            item-key="id"
            handle=".cascade-drag"
            ghost-class="opacity-40"
            animation="150"
            class="flex flex-col gap-2"
            @end="onReorderChains"
          >
            <template #item="{ element, index }">
              <div
                class="flex items-center gap-3 rounded-lg bg-n-alpha-1 border border-n-weak px-3 py-2.5 group"
              >
                <div
                  class="flex items-center justify-center size-5 rounded-full bg-n-alpha-2 text-[11px] font-semibold text-n-slate-10 flex-shrink-0"
                >
                  {{ index + 1 }}
                </div>
                <span
                  class="cascade-drag i-lucide-grip-vertical size-4 text-n-slate-8 hover:text-n-slate-11 cursor-grab flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity"
                />
                <span
                  :class="inboxIcon(element)"
                  class="size-5 flex-shrink-0 text-n-slate-9"
                />
                <span
                  class="flex-1 text-sm font-medium text-n-slate-12 truncate min-w-0"
                >
                  {{ element.name }}
                </span>
                <span
                  v-if="index < serviceChain.length - 1"
                  class="i-lucide-arrow-right size-3.5 text-n-slate-7 flex-shrink-0"
                />
                <button
                  class="ml-auto flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity p-1 rounded hover:bg-n-alpha-2 text-n-slate-9 hover:text-ruby-10"
                  @click="removeFromChain(serviceChain, index)"
                >
                  <span class="i-lucide-x size-3.5" />
                </button>
              </div>
            </template>
          </Draggable>

          <div v-if="!showCascadeLoading" class="mt-3 relative">
            <Button
              variant="ghost"
              size="sm"
              icon="i-lucide-plus"
              :label="t('NOTIFICATION_TEMPLATES.CASCADE.ADD_CHANNEL')"
              :disabled="availableForService.length === 0"
              @click="showServicePicker = !showServicePicker"
            />
            <div
              v-if="showServicePicker && availableForService.length"
              class="absolute top-full left-0 mt-1 z-20 bg-n-solid-3 border border-n-weak rounded-lg shadow-lg py-1 min-w-52 max-h-60 overflow-y-auto"
            >
              <button
                v-for="inbox in availableForService"
                :key="inbox.id"
                class="flex items-center gap-2.5 w-full px-3 py-2 hover:bg-n-alpha-1 text-sm text-n-slate-12 text-left"
                @click="
                  addToChain(serviceChain, inbox);
                  showServicePicker = false;
                "
              >
                <span
                  :class="inboxIcon(inbox)"
                  class="size-4 text-n-slate-9 flex-shrink-0"
                />
                {{ inbox.name }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- How cascade works hint -->
    <div
      class="rounded-lg bg-n-alpha-1 border border-n-weak px-4 py-3 flex gap-3"
    >
      <span class="i-lucide-info size-4 text-n-slate-9 flex-shrink-0 mt-0.5" />
      <p class="text-xs text-n-slate-10 leading-relaxed">
        {{ t('NOTIFICATION_TEMPLATES.CASCADE.HOW_IT_WORKS') }}
      </p>
    </div>

    <!-- Save button -->
    <div class="flex justify-end">
      <Button
        icon="i-lucide-check"
        :is-loading="uiFlags.isSavingCascade"
        :disabled="showCascadeLoading"
        :label="t('NOTIFICATION_TEMPLATES.CASCADE.SAVE')"
        @click="handleSave"
      />
    </div>
  </div>
</template>
