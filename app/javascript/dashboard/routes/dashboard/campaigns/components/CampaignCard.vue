<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  campaign: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['edit', 'delete', 'preview', 'sendNow']);

const { t } = useI18n();

const menuOpen = ref(false);

const toggleMenu = () => {
  menuOpen.value = !menuOpen.value;
};

const closeMenu = () => {
  menuOpen.value = false;
};

const handlePreview = () => {
  closeMenu();
  emit('preview', props.campaign);
};

const handleEdit = () => {
  closeMenu();
  emit('edit', props.campaign);
};

const handleDelete = () => {
  closeMenu();
  emit('delete', props.campaign);
};

const handleSendNow = () => {
  closeMenu();
  emit('sendNow', props.campaign);
};

const displayMessage = computed(() => {
  if (props.campaign.messages?.length) {
    const first = props.campaign.messages[0];
    return typeof first === 'string' ? first : (first.text ?? '');
  }
  return props.campaign.messageText || props.campaign.message || '';
});

const formattedScheduledAt = computed(() => {
  if (!props.campaign.scheduled_at) return '';
  const date = new Date(props.campaign.scheduled_at);
  return date.toLocaleString();
});

const formattedLastSent = computed(() => {
  if (!props.campaign.last_sent_at) return '';
  const date = new Date(props.campaign.last_sent_at);
  return date.toLocaleString();
});

const progressPercent = computed(
  () => props.campaign.delivery_progress_percent || 0
);
const audienceCount = computed(() => props.campaign.audience_count || 0);
const sentCount = computed(() => props.campaign.sent_count || 0);
const failedCount = computed(() => props.campaign.failed_count || 0);
const deliveryStatus = computed(
  () => props.campaign.delivery_status || 'scheduled'
);

const statusColor = computed(() => {
  const colors = {
    scheduled: 'text-n-blue-11 bg-n-blue-3',
    in_progress: 'text-n-amber-11 bg-n-amber-3',
    completed: 'text-n-teal-11 bg-n-teal-3',
  };
  return colors[deliveryStatus.value] || 'text-n-text-body bg-n-slate-3';
});

const progressColor = computed(() => {
  if (failedCount.value > 0 && deliveryStatus.value === 'completed') {
    return 'stroke-n-ruby-9';
  }
  const colors = {
    scheduled: 'stroke-n-blue-9',
    in_progress: 'stroke-n-amber-9',
    completed: 'stroke-n-teal-9',
  };
  return colors[deliveryStatus.value] || 'stroke-n-slate-9';
});

const statusLabel = computed(() => {
  const labels = {
    scheduled: t('CAMPAIGNS.CARD.STATUS_SCHEDULED'),
    in_progress: t('CAMPAIGNS.CARD.STATUS_IN_PROGRESS'),
    completed: t('CAMPAIGNS.CARD.STATUS_COMPLETED'),
  };
  return labels[deliveryStatus.value] || deliveryStatus.value;
});

const circumference = 2 * Math.PI * 14;
const strokeDashoffset = computed(() => {
  const progress = progressPercent.value / 100;
  return circumference * (1 - progress);
});
</script>

<template>
  <div
    class="relative flex items-center justify-between p-4 rounded-xl border border-n-border-glass-soft border-l-[3px] border-l-violet-400 bg-n-glass-soft hover:border-n-border-glass hover:shadow-md transition-all duration-200 cursor-pointer w-full"
    :class="{ 'opacity-60': !campaign.enabled }"
    @click="handleEdit"
  >
    <div class="flex items-center gap-4 flex-1 min-w-0">
      <div class="flex flex-col gap-1.5 flex-1 min-w-0">
        <div class="flex items-center gap-2">
          <span
            class="size-2.5 rounded-full flex-shrink-0"
            :class="campaign.enabled ? 'bg-n-teal-9' : 'bg-n-slate-8'"
          />
          <h3
            class="text-base font-semibold text-n-text-display leading-snug truncate"
          >
            {{ campaign.name || campaign.title }}
          </h3>
          <span
            class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium bg-violet-100 dark:bg-violet-900/40 text-violet-700 dark:text-violet-300 whitespace-nowrap"
          >
            {{ t('CAMPAIGNS.BADGE') }}
          </span>
        </div>

        <p class="text-sm text-n-text-body/60 truncate max-w-2xl">
          {{ displayMessage }}
        </p>
      </div>

      <div class="flex items-center gap-4">
        <div class="flex items-center gap-3">
          <div class="relative size-9 flex-shrink-0">
            <svg class="size-9 -rotate-90" viewBox="0 0 32 32">
              <circle
                cx="16"
                cy="16"
                r="14"
                fill="none"
                stroke="currentColor"
                stroke-width="3"
                class="text-n-slate-3"
              />
              <circle
                cx="16"
                cy="16"
                r="14"
                fill="none"
                :stroke-width="3"
                :class="progressColor"
                :stroke-dasharray="circumference"
                :stroke-dashoffset="strokeDashoffset"
                stroke-linecap="round"
                class="transition-all duration-300"
              />
            </svg>
            <span
              class="absolute inset-0 flex items-center justify-center text-[10px] font-semibold text-n-text-display"
            >
              {{
                t('CAMPAIGNS.CARD.PROGRESS_PERCENT', {
                  percent: progressPercent,
                })
              }}
            </span>
          </div>
          <div class="flex flex-col min-w-0">
            <span class="text-xs text-n-text-body whitespace-nowrap">
              {{
                t('CAMPAIGNS.CARD.SENT_OF_TOTAL', {
                  sent: sentCount,
                  total: audienceCount,
                })
              }}
            </span>
            <span v-if="failedCount > 0" class="text-[10px] text-n-ruby-11">
              {{ t('CAMPAIGNS.CARD.FAILED_COUNT', { count: failedCount }) }}
            </span>
          </div>
        </div>

        <span
          class="inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-medium whitespace-nowrap"
          :class="statusColor"
        >
          {{ statusLabel }}
        </span>

        <div
          v-if="campaign.scheduled_at && deliveryStatus === 'scheduled'"
          class="flex flex-col text-right w-32"
        >
          <span class="text-[10px] text-n-slate-9">
            {{ t('CAMPAIGNS.SCHEDULED') }}
          </span>
          <span class="text-xs text-n-text-body whitespace-nowrap">
            {{ formattedScheduledAt }}
          </span>
        </div>
        <div
          v-else-if="campaign.last_sent_at"
          class="flex flex-col text-right w-32"
        >
          <span class="text-[10px] text-n-slate-9">
            {{ t('NOTIFICATION_TEMPLATES.LAST_SENT') }}
          </span>
          <span class="text-xs text-n-text-body whitespace-nowrap">
            {{ formattedLastSent }}
          </span>
        </div>
        <div v-else-if="!sentCount" class="flex items-center justify-end w-32">
          <Button
            size="xs"
            icon="i-lucide-send"
            :label="t('CAMPAIGNS.SEND_NOW')"
            @click.stop="handleSendNow"
          />
        </div>
      </div>
    </div>

    <OnClickOutside @trigger="closeMenu">
      <div class="relative flex-shrink-0 ml-2">
        <Button
          variant="ghost"
          color="slate"
          size="sm"
          icon="i-lucide-ellipsis"
          @click.stop="toggleMenu"
        />
        <div
          v-if="menuOpen"
          class="absolute right-0 top-10 z-50 min-w-36 rounded-lg border border-n-border-glass-soft bg-n-glass-soft shadow-lg py-1"
        >
          <button
            class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-text-display hover:bg-n-alpha-1 transition-colors"
            @click.stop="handlePreview"
          >
            <span class="i-lucide-eye size-4 text-n-text-body/60" />
            {{ t('NOTIFICATION_TEMPLATES.PREVIEW.BUTTON_TEXT') }}
          </button>
          <button
            class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-text-display hover:bg-n-alpha-1 transition-colors"
            @click.stop="handleEdit"
          >
            <span class="i-lucide-pencil size-4 text-n-text-body/60" />
            {{ t('NOTIFICATION_TEMPLATES.EDIT.BUTTON_TEXT') }}
          </button>
          <button
            class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-ruby-11 hover:bg-n-alpha-1 transition-colors"
            @click.stop="handleDelete"
          >
            <span class="i-lucide-trash-2 size-4" />
            {{ t('NOTIFICATION_TEMPLATES.DELETE.BUTTON_TEXT') }}
          </button>
        </div>
      </div>
    </OnClickOutside>
  </div>
</template>
