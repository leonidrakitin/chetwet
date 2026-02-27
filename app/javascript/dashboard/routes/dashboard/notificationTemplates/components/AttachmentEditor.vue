<script setup>
import { ref, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import VariablePicker from './VariablePicker.vue';

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const MAX_ATTACHMENTS = 10;

const showLinkForm = ref(false);
const linkLabel = ref('');
const linkUrl = ref('');
const activeLinkInputRef = ref(null);
const linkLabelRef = ref(null);
const linkUrlRef = ref(null);

let nextIdCounter = 1;
const genId = () => {
  nextIdCounter += 1;
  return `att-${Date.now()}-${nextIdCounter}`;
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

const removeAttachment = id => {
  emit(
    'update:modelValue',
    props.modelValue.filter(a => a.id !== id)
  );
};

const addFileAttachment = (type, event) => {
  const fileList = Array.from(event.target.files ?? []);
  if (!fileList.length) return;
  const newAttachments = [...props.modelValue];
  fileList.forEach(file => {
    if (newAttachments.length < MAX_ATTACHMENTS) {
      newAttachments.push({ id: genId(), type, name: file.name, url: '' });
    }
  });
  emit('update:modelValue', newAttachments);
  event.target.value = ''; // eslint-disable-line no-param-reassign
};

const addLink = () => {
  if (!linkLabel.value.trim() || !linkUrl.value.trim()) return;
  if (props.modelValue.length >= MAX_ATTACHMENTS) return;
  emit('update:modelValue', [
    ...props.modelValue,
    {
      id: genId(),
      type: 'link',
      name: linkLabel.value.trim(),
      url: linkUrl.value.trim(),
    },
  ]);
  linkLabel.value = '';
  linkUrl.value = '';
  showLinkForm.value = false;
};

const insertVariable = text => {
  const input = activeLinkInputRef.value;
  if (input) {
    const start = input.selectionStart ?? input.value.length;
    const end = input.selectionEnd ?? start;
    const before = input.value.slice(0, start);
    const after = input.value.slice(end);
    const newValue = before + text + after;
    if (input === linkLabelRef.value) linkLabel.value = newValue;
    else linkUrl.value = newValue;
    nextTick(() => {
      input.setSelectionRange(start + text.length, start + text.length);
      input.focus();
    });
    return;
  }
  linkUrl.value += text;
};

const setActiveLinkInput = refOrEl => {
  activeLinkInputRef.value = refOrEl?.value ?? refOrEl;
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <label class="text-sm font-medium text-n-slate-12">
      {{ t('NOTIFICATION_TEMPLATES.ATTACHMENTS.LABEL') }}
    </label>

    <!-- Existing attachments list -->
    <div v-if="modelValue.length" class="flex flex-col gap-1">
      <div
        v-for="att in modelValue"
        :key="att.id"
        class="flex items-center gap-2 rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2"
      >
        <span
          class="size-4 text-n-slate-10 flex-shrink-0"
          :class="getAttachmentIcon(att.type)"
        />
        <span class="flex-1 text-sm text-n-slate-12 truncate">{{
          att.name
        }}</span>
        <a
          v-if="att.url"
          :href="att.url"
          target="_blank"
          rel="noopener noreferrer"
          class="text-xs text-n-blue-11 hover:underline flex-shrink-0"
        >
          <span class="i-lucide-external-link size-3.5" />
        </a>
        <button
          class="text-n-slate-10 hover:text-n-ruby-11 transition-colors flex-shrink-0"
          @click="removeAttachment(att.id)"
        >
          <span class="i-lucide-x size-4" />
        </button>
      </div>
    </div>

    <p
      v-if="modelValue.length >= MAX_ATTACHMENTS"
      class="text-xs text-n-slate-10"
    >
      {{ t('NOTIFICATION_TEMPLATES.ATTACHMENTS.MAX_REACHED') }}
    </p>

    <!-- Add buttons -->
    <div
      v-if="modelValue.length < MAX_ATTACHMENTS"
      class="flex flex-wrap gap-2"
    >
      <label
        class="inline-flex items-center gap-1.5 cursor-pointer rounded-lg border border-dashed border-n-weak px-3 py-1.5 text-xs text-n-slate-10 hover:border-n-brand hover:text-n-slate-12 transition-colors"
      >
        <span class="i-lucide-file size-3.5" />
        {{ t('NOTIFICATION_TEMPLATES.ATTACHMENTS.ADD_FILE') }}
        <input
          type="file"
          class="hidden"
          multiple
          @change="addFileAttachment('file', $event)"
        />
      </label>

      <label
        class="inline-flex items-center gap-1.5 cursor-pointer rounded-lg border border-dashed border-n-weak px-3 py-1.5 text-xs text-n-slate-10 hover:border-n-brand hover:text-n-slate-12 transition-colors"
      >
        <span class="i-lucide-image size-3.5" />
        {{ t('NOTIFICATION_TEMPLATES.ATTACHMENTS.ADD_PHOTO') }}
        <input
          type="file"
          accept="image/*"
          class="hidden"
          multiple
          @change="addFileAttachment('photo', $event)"
        />
      </label>

      <label
        class="inline-flex items-center gap-1.5 cursor-pointer rounded-lg border border-dashed border-n-weak px-3 py-1.5 text-xs text-n-slate-10 hover:border-n-brand hover:text-n-slate-12 transition-colors"
      >
        <span class="i-lucide-video size-3.5" />
        {{ t('NOTIFICATION_TEMPLATES.ATTACHMENTS.ADD_VIDEO') }}
        <input
          type="file"
          accept="video/*"
          class="hidden"
          multiple
          @change="addFileAttachment('video', $event)"
        />
      </label>

      <button
        class="inline-flex items-center gap-1.5 rounded-lg border border-dashed border-n-weak px-3 py-1.5 text-xs text-n-slate-10 hover:border-n-brand hover:text-n-slate-12 transition-colors"
        @click="showLinkForm = !showLinkForm"
      >
        <span class="i-lucide-link size-3.5" />
        {{ t('NOTIFICATION_TEMPLATES.ATTACHMENTS.ADD_LINK') }}
      </button>

      <VariablePicker @insert="insertVariable" />
    </div>

    <!-- Link form -->
    <div
      v-if="showLinkForm"
      class="flex flex-col gap-2 rounded-lg border border-n-weak bg-n-alpha-1 p-3"
    >
      <input
        ref="linkLabelRef"
        v-model="linkLabel"
        type="text"
        :placeholder="t('NOTIFICATION_TEMPLATES.ATTACHMENTS.LINK_LABEL')"
        class="h-8 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
        @focus="setActiveLinkInput(linkLabelRef)"
      />
      <input
        ref="linkUrlRef"
        v-model="linkUrl"
        type="url"
        :placeholder="t('NOTIFICATION_TEMPLATES.ATTACHMENTS.LINK_URL')"
        class="h-8 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
        @focus="setActiveLinkInput(linkUrlRef)"
      />
      <div class="flex gap-2">
        <button
          class="rounded-lg bg-n-brand px-3 py-1.5 text-xs text-white hover:bg-n-brand/90 transition-colors"
          @click="addLink"
        >
          {{ t('NOTIFICATION_TEMPLATES.ATTACHMENTS.ADD_LINK') }}
        </button>
        <button
          class="rounded-lg border border-n-weak px-3 py-1.5 text-xs text-n-slate-10 hover:bg-n-alpha-1 transition-colors"
          @click="showLinkForm = false"
        >
          {{ t('NOTIFICATION_TEMPLATES.COMMON.CANCEL') }}
        </button>
      </div>
    </div>
  </div>
</template>
