<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import { getChainLabel } from '../helpers/chainLabel';

const props = defineProps({
  template: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['edit', 'delete', 'clone', 'preview']);

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
const menuOpen = ref(false);

const toggleMenu = () => {
  menuOpen.value = !menuOpen.value;
};

const closeMenu = () => {
  menuOpen.value = false;
};

const handlePreview = () => {
  closeMenu();
  emit('preview', props.template);
};

const handleEdit = () => {
  closeMenu();
  emit('edit', props.template);
};

const handleClone = () => {
  closeMenu();
  emit('clone', props.template.id);
};

const handleDelete = () => {
  closeMenu();
  emit('delete', props.template);
};

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

const borderColorClass = computed(() => {
  const colors = {
    event: 'border-l-indigo-400',
    time: 'border-l-amber-400',
    interval: 'border-l-emerald-400',
  };
  return colors[props.template.type] ?? 'border-l-n-slate-8';
});
</script>

<template>
  <div
    class="relative flex flex-col gap-3 p-4 rounded-xl border border-n-weak border-l-[3px] bg-n-solid-1 hover:border-n-strong hover:shadow-md transition-all duration-200 cursor-pointer"
    :class="[borderColorClass, { 'opacity-60': !template.enabled }]"
    @click="handleEdit"
  >
    <!-- Top row: name + status dot | menu -->
    <div class="flex items-start justify-between gap-2">
      <div class="flex items-center gap-2 min-w-0">
        <span
          class="size-2 rounded-full flex-shrink-0"
          :class="template.enabled ? 'bg-n-teal-9' : 'bg-n-slate-8'"
        />
        <h3 class="text-sm font-semibold text-n-slate-12 leading-snug truncate">
          {{ template.name }}
        </h3>
      </div>
      <OnClickOutside @trigger="closeMenu">
        <div class="relative flex-shrink-0">
          <Button
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-ellipsis"
            @click.stop="toggleMenu"
          />
          <div
            v-if="menuOpen"
            class="absolute right-0 top-8 z-50 min-w-36 rounded-lg border border-n-weak bg-n-solid-1 shadow-lg py-1"
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
              class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-slate-12 hover:bg-n-alpha-1 transition-colors"
              @click.stop="handleClone"
            >
              <span class="i-lucide-copy size-4 text-n-slate-10" />
              {{ t('NOTIFICATION_TEMPLATES.CLONE.BUTTON_TEXT') }}
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

    <div class="flex flex-col gap-1">
      <!-- Inline message bubbles preview -->
      <div
        v-for="(text, idx) in processedMessages"
        :key="idx"
        class="rounded-xl rounded-tr-sm bg-n-brand px-3 py-2 text-xs text-white max-w-full line-clamp-2 leading-relaxed whitespace-pre-wrap break-words"
      >
        {{ text }}
      </div>

      <!-- Attachments icons -->
      <div v-if="allAttachments.length" class="flex flex-wrap gap-1 mt-1">
        <span
          v-for="att in allAttachments"
          :key="att.id"
          class="flex items-center gap-1 text-xs text-n-slate-10"
        >
          <span class="size-3" :class="getAttachmentIcon(att.type)" />
          <span class="max-w-20 truncate">{{ att.name }}</span>
        </span>
      </div>

      <!-- Buttons compact view -->
      <div v-if="allButtons.length" class="flex flex-wrap gap-1 mt-1">
        <span
          v-for="btn in allButtons"
          :key="btn.id"
          class="inline-flex items-center rounded-full border border-n-blue-9 px-2 py-0.5 text-xs text-n-blue-11"
        >
          {{ btn.label }}
        </span>
      </div>
    </div>

    <div class="flex items-center">
      <span
        class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium bg-n-brand/10 text-n-blue-11"
      >
        {{ eventLabel(template) }}
      </span>
    </div>
  </div>
</template>
