<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

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
</script>

<template>
  <div class="flex flex-col gap-2">
    <label class="text-sm font-medium text-n-text-display">
      {{ t('NOTIFICATION_TEMPLATES.ATTACHMENTS.LABEL') }}
    </label>

    <!-- Existing attachments list -->
    <div v-if="modelValue.length" class="flex flex-col gap-1">
      <div
        v-for="att in modelValue"
        :key="att.id"
        class="flex items-center gap-2 rounded-lg border border-n-border-glass-soft bg-n-alpha-1 px-3 py-2"
      >
        <span
          class="size-4 text-n-text-body/60 flex-shrink-0"
          :class="getAttachmentIcon(att.type)"
        />
        <span class="flex-1 text-sm text-n-text-display truncate">{{
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
          class="text-n-text-body/60 hover:text-n-ruby-11 transition-colors flex-shrink-0"
          @click="removeAttachment(att.id)"
        >
          <span class="i-lucide-x size-4" />
        </button>
      </div>
    </div>

    <p
      v-if="modelValue.length >= MAX_ATTACHMENTS"
      class="text-xs text-n-text-body/60"
    >
      {{ t('NOTIFICATION_TEMPLATES.ATTACHMENTS.MAX_REACHED') }}
    </p>

    <!-- Add buttons -->
    <div
      v-if="modelValue.length < MAX_ATTACHMENTS"
      class="flex flex-wrap gap-2"
    >
      <label
        class="inline-flex items-center gap-1.5 cursor-pointer rounded-lg border border-dashed border-n-border-glass-soft px-3 py-1.5 text-xs text-n-text-body/60 hover:border-n-brand hover:text-n-text-display transition-colors"
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
        class="inline-flex items-center gap-1.5 cursor-pointer rounded-lg border border-dashed border-n-border-glass-soft px-3 py-1.5 text-xs text-n-text-body/60 hover:border-n-brand hover:text-n-text-display transition-colors"
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
        class="inline-flex items-center gap-1.5 cursor-pointer rounded-lg border border-dashed border-n-border-glass-soft px-3 py-1.5 text-xs text-n-text-body/60 hover:border-n-brand hover:text-n-text-display transition-colors"
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
        class="inline-flex items-center gap-1.5 rounded-lg border border-dashed border-n-border-glass-soft px-3 py-1.5 text-xs text-n-text-body/60 hover:border-n-brand hover:text-n-text-display transition-colors"
        @click="showLinkForm = !showLinkForm"
      >
        <span class="i-lucide-link size-3.5" />
        {{ t('NOTIFICATION_TEMPLATES.ATTACHMENTS.ADD_LINK') }}
      </button>
    </div>

    <!-- Link form -->
    <div
      v-if="showLinkForm"
      class="flex flex-col gap-2 rounded-lg border border-n-border-glass-soft bg-n-alpha-1 p-3"
    >
      <input
        v-model="linkLabel"
        type="text"
        :placeholder="t('NOTIFICATION_TEMPLATES.ATTACHMENTS.LINK_LABEL')"
        class="h-8 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
      />
      <input
        v-model="linkUrl"
        type="url"
        :placeholder="t('NOTIFICATION_TEMPLATES.ATTACHMENTS.LINK_URL')"
        class="h-8 w-full rounded-lg border border-n-border-glass-soft bg-n-glass-soft px-3 text-sm text-n-text-display placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
      />
      <div class="flex gap-2">
        <button
          class="rounded-lg bg-n-brand px-3 py-1.5 text-xs text-white hover:bg-n-brand/90 transition-colors"
          @click="addLink"
        >
          {{ t('NOTIFICATION_TEMPLATES.ATTACHMENTS.ADD_LINK') }}
        </button>
        <button
          class="rounded-lg border border-n-border-glass-soft px-3 py-1.5 text-xs text-n-text-body/60 hover:bg-n-alpha-1 transition-colors"
          @click="showLinkForm = false"
        >
          {{ t('NOTIFICATION_TEMPLATES.COMMON.CANCEL') }}
        </button>
      </div>
    </div>
  </div>
</template>
