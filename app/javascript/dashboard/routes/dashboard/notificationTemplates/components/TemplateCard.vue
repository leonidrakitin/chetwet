<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import { getChainLabel } from '../helpers/chainLabel';

const props = defineProps({
  template: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['edit', 'delete', 'preview']);

const EXAMPLE_VALUES = {
  client_name: 'Иван Иванов',
  service_name: 'Стрижка',
  branch_name: 'Центральный офис',
  master_name: 'Мария',
  price: '1 500 ₽',
  date: '15 марта',
  time: '14:30',
};

const getAttachmentIcon = type => {
  const icons = {
    file: 'i-lucide-file',
    photo: 'i-lucide-image',
    video: 'i-lucide-video',
    link: 'i-lucide-link',
  };
  return icons[type] ?? 'i-lucide-paperclip';
};

const { t } = useI18n();

const handlePreview = () => emit('preview', props.template);
const handleEdit = () => emit('edit', props.template);
const handleDelete = () => emit('delete', props.template);

const processedMessages = computed(() => {
  let rawTexts;
  if (props.template.messages?.length) {
    const first = props.template.messages[0];
    rawTexts =
      typeof first === 'string'
        ? props.template.messages
        : props.template.messages.map(m => m.text ?? '');
  } else if (props.template.messageText) {
    rawTexts = [props.template.messageText];
  } else {
    rawTexts = [];
  }
  return rawTexts
    .map(text =>
      text.replace(
        /@(\w+)|\{(\w+)\}/g,
        (match, atVariable, legacyVariable) =>
          EXAMPLE_VALUES[atVariable || legacyVariable] ?? match
      )
    )
    .filter(Boolean);
});

const firstMessage = computed(() => processedMessages.value[0] ?? '');
const extraMessageCount = computed(() => processedMessages.value.length - 1);

const allAttachments = computed(() => {
  if (!props.template.messages?.length) return props.template.attachments ?? [];
  const first = props.template.messages[0];
  if (typeof first === 'string') return props.template.attachments ?? [];
  return props.template.messages.flatMap(m => m.attachments ?? []);
});

const allButtons = computed(() => {
  if (!props.template.messages?.length) return props.template.buttons ?? [];
  const first = props.template.messages[0];
  if (typeof first === 'string') return props.template.buttons ?? [];
  return props.template.messages.flatMap(m => m.buttons ?? []);
});

const eventLabel = template => getChainLabel(template, t);

// Show more
const messageRef = ref(null);
const isExpanded = ref(false);
const hasOverflow = ref(false);

onMounted(() => {
  if (messageRef.value) {
    hasOverflow.value =
      messageRef.value.scrollHeight > messageRef.value.clientHeight;
  }
});
</script>

<template>
  <CardLayout layout="row">
    <div
      class="flex flex-col items-start flex-1 min-w-0 gap-2 cursor-pointer"
      @click="handleEdit"
    >
      <!-- Row 1: name + status badge -->
      <div class="flex items-center gap-2 w-full">
        <span
          class="text-base font-medium text-n-slate-12 line-clamp-1 flex-1"
          :class="{ 'opacity-60': !template.enabled }"
        >
          {{ template.name }}
        </span>
        <span
          class="text-xs font-medium inline-flex items-center h-6 px-2 py-0.5 rounded-md bg-n-alpha-2 flex-shrink-0"
          :class="template.enabled ? 'text-n-teal-11' : 'text-n-slate-12'"
        >
          {{
            template.enabled
              ? t('NOTIFICATION_TEMPLATES.CARD.ENABLED')
              : t('NOTIFICATION_TEMPLATES.CARD.DISABLED')
          }}
        </span>
      </div>

      <!-- Row 2: message preview with show more -->
      <div v-if="firstMessage" class="w-full">
        <div
          ref="messageRef"
          class="text-sm text-n-slate-11 [&>p]:mb-0"
          :class="isExpanded ? '' : 'line-clamp-2'"
        >
          {{ firstMessage
          }}<span
            v-if="extraMessageCount > 0 && !isExpanded"
            class="text-n-slate-9"
          >
            {{ ` +${extraMessageCount}` }}
          </span>
        </div>
        <button
          v-if="hasOverflow || isExpanded"
          class="text-xs text-n-blue-11 hover:underline mt-0.5"
          @click.stop="isExpanded = !isExpanded"
        >
          {{
            isExpanded
              ? t('NOTIFICATION_TEMPLATES.CARD.SHOW_LESS')
              : t('NOTIFICATION_TEMPLATES.CARD.SHOW_MORE')
          }}
        </button>
      </div>

      <!-- Row 3: event badge + attachments + buttons indicators -->
      <div class="flex items-center gap-2 w-full h-6 overflow-hidden">
        <span
          class="inline-flex items-center rounded-md px-2 py-0.5 text-xs font-medium bg-n-alpha-2 text-n-slate-11 truncate max-w-xs"
        >
          {{ eventLabel(template) }}
        </span>
        <div
          v-if="allAttachments.length"
          class="flex items-center gap-1 flex-shrink-0"
        >
          <span
            v-for="att in allAttachments"
            :key="att.id"
            :class="getAttachmentIcon(att.type)"
            class="size-3.5 text-n-slate-9"
          />
        </div>
        <div
          v-if="allButtons.length"
          class="flex items-center gap-1 flex-shrink-0"
        >
          <span class="i-lucide-mouse-pointer-click size-3.5 text-n-slate-9" />
          <span class="text-xs text-n-slate-9">{{ allButtons.length }}</span>
        </div>
      </div>
    </div>

    <!-- Action buttons -->
    <div class="flex items-center gap-2 flex-shrink-0">
      <Button
        variant="faded"
        size="sm"
        color="slate"
        icon="i-lucide-eye"
        @click.stop="handlePreview"
      />
      <Button
        variant="faded"
        size="sm"
        color="slate"
        icon="i-lucide-pencil"
        @click.stop="handleEdit"
      />
      <Button
        variant="faded"
        size="sm"
        color="ruby"
        icon="i-lucide-trash"
        @click.stop="handleDelete"
      />
    </div>
  </CardLayout>
</template>
