<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { getInboxIconByType } from 'dashboard/helper/inbox';

const { t } = useI18n();
const store = useStore();

const uiFlags = computed(
  () => store.getters['notificationTemplates/getUIFlags']
);
const savedLimits = computed(
  () => store.getters['notificationTemplates/getDeliveryLimits']
);
const inboxesUiFlags = computed(() => store.getters['inboxes/getUIFlags']);

const isLoading = computed(
  () =>
    uiFlags.value.isFetchingDeliveryLimits ||
    uiFlags.value.isFetchingCascade ||
    inboxesUiFlags.value.isFetching
);
const isSaving = computed(
  () => uiFlags.value.isSavingDeliveryLimits || uiFlags.value.isSavingCascade
);

const quietHoursFrom = ref('');
const quietHoursTo = ref('');
const maxPerDay = ref(null);
const stopIfReplied = ref(false);
const stopIfRepliedRetryMinutes = ref(15);
const skipIfHasActiveDialog = ref(false);
const perContactGapMinutes = ref(0);
const marketingChain = ref([]);
const serviceChain = ref([]);

const hasStartedBootstrap = ref(false);

const hydrateFromStore = () => {
  const limits = savedLimits.value || {};
  maxPerDay.value = limits.max_per_day ?? null;
  stopIfReplied.value = limits.stop_if_replied ?? false;
  stopIfRepliedRetryMinutes.value = limits.stop_if_replied_retry_minutes ?? 15;
  skipIfHasActiveDialog.value = limits.skip_if_has_active_dialog ?? false;
  perContactGapMinutes.value = limits.per_contact_gap_minutes ?? 0;
  quietHoursFrom.value = limits.quiet_hours_from ?? '22:00';
  quietHoursTo.value = limits.quiet_hours_to ?? '08:00';
};

const cascadeSettings = computed(
  () => store.getters['notificationTemplates/getCascadeSettings']
);

const allInboxes = computed(() => store.getters['inboxes/getInboxes']);

const showMarketingPicker = ref(false);
const showServicePicker = ref(false);

const buildChain = (ids, inboxes) => {
  const byId = Object.fromEntries(inboxes.map(i => [i.id, i]));
  return ids.filter(id => byId[id]).map(id => byId[id]);
};

const hydrateChainsFromStore = () => {
  const inboxes = allInboxes.value;
  const settings = cascadeSettings.value || {};
  if (!inboxes.length) return;
  marketingChain.value = buildChain(settings.marketing || [], inboxes);
  serviceChain.value = buildChain(settings.service || [], inboxes);
};

watch(
  [cascadeSettings, allInboxes],
  () => {
    if (!allInboxes.value.length || hasStartedBootstrap.value) return;
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

const addToChain = (chain, inbox) => {
  chain.push(inbox);
};

const removeFromChain = (chain, index) => {
  chain.splice(index, 1);
};

const inboxIcon = inbox =>
  getInboxIconByType(inbox.channel_type, inbox.medium, 'outline');

const handleSave = async () => {
  try {
    await store.dispatch('notificationTemplates/saveDeliveryLimits', {
      max_per_day: maxPerDay.value || null,
      stop_if_replied: stopIfReplied.value,
      stop_if_replied_retry_minutes: stopIfRepliedRetryMinutes.value,
      skip_if_has_active_dialog: skipIfHasActiveDialog.value,
      per_contact_gap_minutes: perContactGapMinutes.value,
      quiet_hours_from: quietHoursFrom.value,
      quiet_hours_to: quietHoursTo.value,
    });
    await store.dispatch('notificationTemplates/saveCascadeSettings', {
      marketing: marketingChain.value.map(i => i.id),
      service: serviceChain.value.map(i => i.id),
    });
    useAlert(t('NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.SAVE_SUCCESS'));
  } catch {
    useAlert(t('NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.SAVE_ERROR'));
  }
};

onMounted(async () => {
  if (!allInboxes.value.length) {
    store.dispatch('inboxes/get');
  }
  await Promise.all([
    store.dispatch('notificationTemplates/fetchDeliveryLimits'),
    store.dispatch('notificationTemplates/fetchCascadeSettings'),
  ]);
  hydrateFromStore();
  hydrateChainsFromStore();
  hasStartedBootstrap.value = true;
});
</script>

<template>
  <div class="w-full max-w-4xl mx-auto flex flex-col gap-6">
    <div class="flex flex-col gap-1">
      <h2 class="text-xl font-semibold text-n-text-display">
        {{ t('NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.TITLE') }}
      </h2>
      <p class="text-sm text-n-text-body/60">
        {{ t('NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.DESCRIPTION') }}
      </p>
    </div>

    <div
      v-if="isLoading"
      class="py-10 flex flex-col items-center justify-center gap-2 text-n-slate-9"
    >
      <Spinner :size="24" />
    </div>

    <template v-else>
      <div class="rounded-xl border border-n-border-glass-soft bg-n-glass-soft">
        <div
          class="px-5 py-4 border-b border-n-border-glass-soft rounded-t-xl bg-gradient-to-r from-slate-50/60 to-transparent dark:from-slate-950/20"
        >
          <div class="flex items-center gap-2.5">
            <div
              class="flex items-center justify-center size-8 rounded-lg bg-slate-100 dark:bg-slate-900/40 flex-shrink-0"
            >
              <span
                class="i-lucide-moon size-4 text-slate-600 dark:text-slate-400"
              />
            </div>
            <div>
              <h3 class="text-sm font-semibold text-n-text-display">
                {{
                  t(
                    'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.QUIET_HOURS.TITLE'
                  )
                }}
              </h3>
              <p class="text-xs text-n-slate-9 mt-0.5">
                {{
                  t(
                    'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.QUIET_HOURS.DESCRIPTION'
                  )
                }}
              </p>
            </div>
          </div>
        </div>
        <div class="px-5 py-4">
          <div class="grid grid-cols-2 gap-4">
            <div class="flex flex-col gap-1.5">
              <label class="text-sm font-medium text-n-text-display">
                {{
                  t(
                    'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.QUIET_HOURS.FROM'
                  )
                }}
              </label>
              <Input
                v-model="quietHoursFrom"
                type="time"
                :custom-input-class="['!py-2']"
              />
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-sm font-medium text-n-text-display">
                {{
                  t(
                    'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.QUIET_HOURS.TO'
                  )
                }}
              </label>
              <Input
                v-model="quietHoursTo"
                type="time"
                :custom-input-class="['!py-2']"
              />
            </div>
          </div>
        </div>
      </div>

      <div class="rounded-xl border border-n-border-glass-soft bg-n-glass-soft">
        <div
          class="px-5 py-4 border-b border-n-border-glass-soft rounded-t-xl bg-gradient-to-r from-amber-50/60 to-transparent dark:from-amber-950/20"
        >
          <div class="flex items-center gap-2.5">
            <div
              class="flex items-center justify-center size-8 rounded-lg bg-amber-100 dark:bg-amber-900/40 flex-shrink-0"
            >
              <span
                class="i-lucide-shield-check size-4 text-amber-600 dark:text-amber-400"
              />
            </div>
            <div>
              <h3 class="text-sm font-semibold text-n-text-display">
                {{
                  t(
                    'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.LIMITS.TITLE'
                  )
                }}
              </h3>
              <p class="text-xs text-n-slate-9 mt-0.5">
                {{
                  t(
                    'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.LIMITS.DESCRIPTION'
                  )
                }}
              </p>
            </div>
          </div>
        </div>
        <div class="px-5 py-4 flex flex-col gap-5">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
            <div class="flex flex-col gap-1.5">
              <label class="text-sm font-medium text-n-text-display">
                {{
                  t(
                    'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.LIMITS.MAX_PER_DAY.LABEL'
                  )
                }}
              </label>
              <Input
                v-model="maxPerDay"
                type="number"
                :placeholder="
                  t(
                    'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.LIMITS.MAX_PER_DAY.PLACEHOLDER'
                  )
                "
                :custom-input-class="['!py-2']"
              />
              <p class="text-xs text-n-slate-9">
                {{
                  t(
                    'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.LIMITS.MAX_PER_DAY.HELP'
                  )
                }}
              </p>
            </div>

            <div class="flex flex-col gap-1.5">
              <label class="text-sm font-medium text-n-text-display">
                {{
                  t(
                    'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.LIMITS.PER_CONTACT_GAP.LABEL'
                  )
                }}
              </label>
              <Input
                v-model="perContactGapMinutes"
                type="number"
                :placeholder="
                  t(
                    'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.LIMITS.PER_CONTACT_GAP.PLACEHOLDER'
                  )
                "
                :custom-input-class="['!py-2']"
              />
              <p class="text-xs text-n-slate-9">
                {{
                  t(
                    'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.LIMITS.PER_CONTACT_GAP.HELP'
                  )
                }}
              </p>
            </div>
          </div>

          <div
            class="flex flex-col gap-4 pt-2 border-t border-n-border-glass-soft"
          >
            <div class="flex items-start justify-between gap-4">
              <div class="flex flex-col gap-0.5">
                <label class="text-sm font-medium text-n-text-display">
                  {{
                    t(
                      'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.LIMITS.STOP_IF_REPLIED.LABEL'
                    )
                  }}
                </label>
                <p class="text-xs text-n-slate-9">
                  {{
                    t(
                      'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.LIMITS.STOP_IF_REPLIED.HELP'
                    )
                  }}
                </p>
              </div>
              <Switch v-model="stopIfReplied" />
            </div>

            <div
              v-if="stopIfReplied"
              class="flex flex-col gap-1.5 pl-4 border-l-2 border-amber-200 dark:border-amber-800"
            >
              <label class="text-sm font-medium text-n-text-display">
                {{
                  t(
                    'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.LIMITS.STOP_IF_REPLIED_RETRY_MINUTES.LABEL'
                  )
                }}
              </label>
              <Input
                v-model="stopIfRepliedRetryMinutes"
                type="number"
                :placeholder="
                  t(
                    'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.LIMITS.STOP_IF_REPLIED_RETRY_MINUTES.PLACEHOLDER'
                  )
                "
                :custom-input-class="['!py-2', 'w-32']"
              />
              <p class="text-xs text-n-slate-9">
                {{
                  t(
                    'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.LIMITS.STOP_IF_REPLIED_RETRY_MINUTES.HELP'
                  )
                }}
              </p>
            </div>

            <div class="flex items-start justify-between gap-4">
              <div class="flex flex-col gap-0.5">
                <label class="text-sm font-medium text-n-text-display">
                  {{
                    t(
                      'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.LIMITS.SKIP_IF_HAS_ACTIVE_DIALOG.LABEL'
                    )
                  }}
                </label>
                <p class="text-xs text-n-slate-9">
                  {{
                    t(
                      'NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.LIMITS.SKIP_IF_HAS_ACTIVE_DIALOG.HELP'
                    )
                  }}
                </p>
              </div>
              <Switch v-model="skipIfHasActiveDialog" />
            </div>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div
          class="rounded-xl border border-n-border-glass-soft bg-n-glass-soft"
        >
          <div
            class="px-5 py-4 border-b border-n-border-glass-soft rounded-t-xl bg-gradient-to-r from-violet-50/60 to-transparent dark:from-violet-950/20"
          >
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
                  <h3 class="text-sm font-semibold text-n-text-display">
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
                  {{
                    t('NOTIFICATION_TEMPLATES.CASCADE.MARKETING.LEGAL_NOTICE')
                  }}
                </p>
              </div>
            </div>
          </div>
          <div class="px-5 py-4">
            <div v-if="marketingChain.length === 0" class="py-4 text-center">
              <p class="text-sm text-n-slate-9">
                {{ t('NOTIFICATION_TEMPLATES.CASCADE.EMPTY_CHAIN') }}
              </p>
            </div>
            <div v-else class="flex flex-col gap-2">
              <div
                v-for="(inbox, index) in marketingChain"
                :key="inbox.id"
                class="flex items-center gap-3 rounded-lg bg-n-alpha-1 border border-n-border-glass-soft px-3 py-2.5 group"
              >
                <div
                  class="flex items-center justify-center size-5 rounded-full bg-n-alpha-2 text-[11px] font-semibold text-n-text-body/60 flex-shrink-0"
                >
                  {{ index + 1 }}
                </div>
                <span
                  :class="inboxIcon(inbox)"
                  class="size-5 flex-shrink-0 text-n-slate-9"
                />
                <span
                  class="flex-1 text-sm font-medium text-n-text-display truncate min-w-0"
                >
                  {{ inbox.name }}
                </span>
                <span
                  v-if="index < marketingChain.length - 1"
                  class="i-lucide-arrow-right size-3.5 text-n-slate-7 flex-shrink-0"
                />
                <button
                  class="ml-auto flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity p-1 rounded hover:bg-n-alpha-2 text-n-slate-9 hover:text-ruby-10"
                  @click="removeFromChain(marketingChain, index)"
                >
                  <span class="i-lucide-x size-3.5" />
                </button>
              </div>
            </div>
            <div class="mt-3 relative">
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
                class="absolute top-full left-0 mt-1 z-20 bg-n-solid-3 border border-n-border-glass-soft rounded-lg shadow-lg py-1 min-w-52 max-h-60 overflow-y-auto"
              >
                <button
                  v-for="inbox in availableForMarketing"
                  :key="inbox.id"
                  class="flex items-center gap-2.5 w-full px-3 py-2 hover:bg-n-alpha-1 text-sm text-n-text-display text-left"
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

        <div
          class="rounded-xl border border-n-border-glass-soft bg-n-glass-soft"
        >
          <div
            class="px-5 py-4 border-b border-n-border-glass-soft rounded-t-xl bg-gradient-to-r from-blue-50/60 to-transparent dark:from-blue-950/20"
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
                  <h3 class="text-sm font-semibold text-n-text-display">
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
          <div class="px-5 py-4">
            <div v-if="serviceChain.length === 0" class="py-4 text-center">
              <p class="text-sm text-n-slate-9">
                {{ t('NOTIFICATION_TEMPLATES.CASCADE.EMPTY_CHAIN') }}
              </p>
            </div>
            <div v-else class="flex flex-col gap-2">
              <div
                v-for="(inbox, index) in serviceChain"
                :key="inbox.id"
                class="flex items-center gap-3 rounded-lg bg-n-alpha-1 border border-n-border-glass-soft px-3 py-2.5 group"
              >
                <div
                  class="flex items-center justify-center size-5 rounded-full bg-n-alpha-2 text-[11px] font-semibold text-n-text-body/60 flex-shrink-0"
                >
                  {{ index + 1 }}
                </div>
                <span
                  :class="inboxIcon(inbox)"
                  class="size-5 flex-shrink-0 text-n-slate-9"
                />
                <span
                  class="flex-1 text-sm font-medium text-n-text-display truncate min-w-0"
                >
                  {{ inbox.name }}
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
            </div>
            <div class="mt-3 relative">
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
                class="absolute top-full left-0 mt-1 z-20 bg-n-solid-3 border border-n-border-glass-soft rounded-lg shadow-lg py-1 min-w-52 max-h-60 overflow-y-auto"
              >
                <button
                  v-for="inbox in availableForService"
                  :key="inbox.id"
                  class="flex items-center gap-2.5 w-full px-3 py-2 hover:bg-n-alpha-1 text-sm text-n-text-display text-left"
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

      <div class="flex justify-end">
        <Button
          icon="i-lucide-check"
          :is-loading="isSaving"
          :label="t('NOTIFICATION_TEMPLATES.NOTIFICATIONS_SETTINGS.SAVE')"
          @click="handleSave"
        />
      </div>
    </template>
  </div>
</template>
