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
  return props.campaign.messageText || '';
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
</script>

<template>
  <div
    class="relative flex items-center justify-between p-4 rounded-xl border border-n-weak border-l-[3px] border-l-violet-400 bg-n-solid-1 hover:border-n-strong hover:shadow-md transition-all duration-200 cursor-pointer w-full"
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
            class="text-base font-semibold text-n-slate-12 leading-snug truncate"
          >
            {{ campaign.name }}
          </h3>
          <span
            class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium bg-violet-100 dark:bg-violet-900/40 text-violet-700 dark:text-violet-300 whitespace-nowrap"
          >
            {{ t('CAMPAIGNS.BADGE') }}
          </span>
        </div>

        <p class="text-sm text-n-slate-10 truncate max-w-2xl">
          {{ displayMessage }}
        </p>
      </div>

      <div class="flex items-center gap-6 pr-4">
        <div v-if="campaign.scheduled_at" class="flex flex-col text-right w-36">
          <span class="text-xs text-n-slate-9 mb-0.5">
            {{ t('CAMPAIGNS.SCHEDULED') }}
          </span>
          <span class="text-xs text-n-slate-11 whitespace-nowrap">
            {{ formattedScheduledAt }}
          </span>
        </div>
        <div
          v-else-if="campaign.last_sent_at"
          class="flex flex-col text-right w-36"
        >
          <span class="text-xs text-n-slate-9 mb-0.5">
            {{ t('NOTIFICATION_TEMPLATES.LAST_SENT') }}
          </span>
          <span class="text-xs text-n-slate-11 whitespace-nowrap">
            {{ formattedLastSent }}
          </span>
        </div>
        <div v-else class="flex items-center justify-end w-36">
          <Button
            variant="smooth"
            color="brand"
            size="xs"
            icon="i-lucide-send"
            :label="t('CAMPAIGNS.SEND_NOW')"
            @click.stop="handleSendNow"
          />
        </div>
      </div>
    </div>

    <!-- Actions Menu -->
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
          class="absolute right-0 top-10 z-50 min-w-36 rounded-lg border border-n-weak bg-n-solid-1 shadow-lg py-1"
        >
          <button
            class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-slate-12 hover:bg-n-alpha-1 transition-colors"
            @click.stop="handlePreview"
          >
            <span class="i-lucide-eye size-4 text-n-slate-10" />
            {{ t('NOTIFICATION_TEMPLATES.PREVIEW.BUTTON_TEXT') }}
          </button>
          <button
            class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-slate-12 hover:bg-n-alpha-1 transition-colors"
            @click.stop="handleEdit"
          >
            <span class="i-lucide-pencil size-4 text-n-slate-10" />
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
