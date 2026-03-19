<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  suggestion: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close', 'saved']);

const MAX_IMAGES = 10;

const { t } = useI18n();
const store = useStore();
const { accountId } = useAccount();

const title = ref('');
const description = ref('');
const pendingUploads = ref([]);
const removeAttachmentIds = ref([]);
const fileInputRef = ref(null);
const isUploading = ref(false);
const isSubmitting = ref(false);

const isEditMode = computed(() => Boolean(props.suggestion?.id));

const uiFlags = computed(() => store.getters['suggestions/getUIFlags']);
const isCreating = computed(() => uiFlags.value.isCreating);

const isValid = computed(() => title.value.trim().length > 0);

const visibleExistingImages = computed(() => {
  const imgs = props.suggestion?.images || [];
  return imgs.filter(img => !removeAttachmentIds.value.includes(img.id));
});

const totalImageCount = computed(
  () => visibleExistingImages.value.length + pendingUploads.value.length
);

const canAddMoreImages = computed(() => totalImageCount.value < MAX_IMAGES);

const resolveImageUrl = url => {
  if (!url) return '';
  if (url.startsWith('http')) return url;
  const base = window.chatwootConfig?.hostURL?.replace(/\/$/, '') || '';
  return base ? `${base}${url}` : url;
};

const syncFromSuggestion = () => {
  const s = props.suggestion;
  title.value = s?.title ?? '';
  description.value = s?.description ?? '';
  removeAttachmentIds.value = [];
  pendingUploads.value = [];
};

watch(
  () => props.suggestion,
  () => {
    syncFromSuggestion();
  },
  { immediate: true }
);

const openFilePicker = () => {
  fileInputRef.value?.click();
};

const onFilesSelected = async event => {
  const { files } = event.target;
  if (!files?.length) return;
  event.target.value = '';

  const remaining = MAX_IMAGES - totalImageCount.value;
  if (remaining <= 0) {
    useAlert(t('SUGGESTIONS.IMAGE_LIMIT', { max: MAX_IMAGES }));
    return;
  }

  const imageFiles = Array.from(files)
    .filter(file => file.type.startsWith('image/'))
    .slice(0, remaining);
  if (!imageFiles.length) return;

  isUploading.value = true;
  try {
    const results = await Promise.all(
      imageFiles.map(file => uploadFile(file, accountId.value))
    );
    pendingUploads.value.push(
      ...results.map((result, index) => ({
        blobId: result.blobId,
        previewUrl: result.fileUrl || URL.createObjectURL(imageFiles[index]),
      }))
    );
  } catch {
    useAlert(t('SUGGESTIONS.IMAGE_UPLOAD_ERROR'));
  } finally {
    isUploading.value = false;
  }
};

const removePending = index => {
  const row = pendingUploads.value[index];
  if (row?.previewUrl?.startsWith('blob:')) {
    URL.revokeObjectURL(row.previewUrl);
  }
  pendingUploads.value.splice(index, 1);
};

const removeExisting = attachmentId => {
  removeAttachmentIds.value.push(attachmentId);
};

const onSubmit = async () => {
  if (!isValid.value) return;
  isSubmitting.value = true;
  try {
    const blobIds = pendingUploads.value.map(p => p.blobId);
    if (isEditMode.value) {
      await store.dispatch('suggestions/update', {
        id: props.suggestion.id,
        title: title.value.trim(),
        description: description.value,
        image_blob_signed_ids: blobIds,
        remove_attachment_ids: [...removeAttachmentIds.value],
      });
      useAlert(t('SUGGESTIONS.UPDATE_SUCCESS'));
    } else {
      await store.dispatch('suggestions/create', {
        title: title.value.trim(),
        description: description.value,
        image_blob_signed_ids: blobIds,
      });
      useAlert(t('SUGGESTIONS.CREATE_SUCCESS'));
    }
    emit('saved');
  } catch (error) {
    const status = error?.response?.status;
    if (status === 403) {
      useAlert(t('SUGGESTIONS.UPDATE_FORBIDDEN'));
    } else {
      useAlert(
        isEditMode.value
          ? t('SUGGESTIONS.UPDATE_ERROR')
          : t('SUGGESTIONS.CREATE_ERROR')
      );
    }
  } finally {
    isSubmitting.value = false;
  }
};

const modalTitle = computed(() =>
  isEditMode.value ? t('SUGGESTIONS.EDIT_TITLE') : t('SUGGESTIONS.CREATE_TITLE')
);

const submitLabel = computed(() =>
  isEditMode.value ? t('SUGGESTIONS.SAVE') : t('SUGGESTIONS.SUBMIT')
);

const submitDisabled = computed(
  () =>
    !isValid.value ||
    isSubmitting.value ||
    isUploading.value ||
    (isEditMode.value ? false : isCreating.value)
);
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-n-alpha-black2/60"
    @click.self="emit('close')"
  >
    <div
      class="w-full max-w-3xl max-h-[min(90vh,900px)] overflow-y-auto rounded-2xl bg-n-solid-2 p-6 shadow-xl border border-n-container"
    >
      <h2 class="text-lg font-semibold text-n-slate-12 mb-4">
        {{ modalTitle }}
      </h2>

      <form class="flex flex-col gap-4" @submit.prevent="onSubmit">
        <div>
          <label class="block text-sm font-medium text-n-slate-11 mb-1">
            {{ t('SUGGESTIONS.FIELD_TITLE') }}
          </label>
          <input
            v-model="title"
            type="text"
            :placeholder="t('SUGGESTIONS.FIELD_TITLE_PLACEHOLDER')"
            class="w-full rounded-xl border border-n-container bg-n-solid-3 px-4 py-2 text-sm text-n-slate-12 outline-none focus:border-woot-500"
          />
        </div>

        <div class="min-h-[200px]">
          <label class="block text-sm font-medium text-n-slate-11 mb-1">
            {{ t('SUGGESTIONS.FIELD_DESCRIPTION') }}
          </label>
          <Editor
            v-model="description"
            :editor-key="
              isEditMode && suggestion?.id != null
                ? `suggestion-edit-${suggestion.id}`
                : 'suggestion-new-description'
            "
            :placeholder="t('SUGGESTIONS.FIELD_DESCRIPTION_PLACEHOLDER')"
            :max-length="50000"
            :show-character-count="false"
            :enable-canned-responses="false"
            :enable-variables="false"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-n-slate-11 mb-1">
            {{ t('SUGGESTIONS.PHOTOS_LABEL') }}
          </label>
          <input
            ref="fileInputRef"
            type="file"
            accept="image/*"
            multiple
            class="hidden"
            @change="onFilesSelected"
          />
          <Button
            type="button"
            icon="i-lucide-image-plus"
            variant="faded"
            color="slate"
            size="sm"
            :label="t('SUGGESTIONS.ADD_PHOTOS')"
            :disabled="!canAddMoreImages || isUploading"
            @click="openFilePicker"
          />
          <p class="text-xs text-n-slate-10 mt-1">
            {{ t('SUGGESTIONS.PHOTOS_HINT', { max: MAX_IMAGES }) }}
          </p>

          <div v-if="totalImageCount > 0" class="flex flex-wrap gap-2 mt-3">
            <div
              v-for="img in visibleExistingImages"
              :key="`ex-${img.id}`"
              class="relative group w-20 h-20 rounded-lg overflow-hidden border border-n-container bg-n-solid-3"
            >
              <img
                :src="resolveImageUrl(img.url)"
                alt=""
                class="w-full h-full object-cover"
              />
              <button
                type="button"
                class="absolute inset-0 flex items-center justify-center bg-n-alpha-black2/60 opacity-0 group-hover:opacity-100 transition-opacity"
                :aria-label="t('SUGGESTIONS.REMOVE_PHOTO')"
                @click="removeExisting(img.id)"
              >
                <span class="text-white text-xs font-medium">
                  {{ t('SUGGESTIONS.REMOVE_PHOTO') }}
                </span>
              </button>
            </div>
            <div
              v-for="(p, idx) in pendingUploads"
              :key="`pd-${idx}`"
              class="relative group w-20 h-20 rounded-lg overflow-hidden border border-n-container bg-n-solid-3"
            >
              <img
                :src="p.previewUrl"
                alt=""
                class="w-full h-full object-cover"
              />
              <button
                type="button"
                class="absolute inset-0 flex items-center justify-center bg-n-alpha-black2/60 opacity-0 group-hover:opacity-100 transition-opacity"
                :aria-label="t('SUGGESTIONS.REMOVE_PHOTO')"
                @click="removePending(idx)"
              >
                <span class="text-white text-xs font-medium">
                  {{ t('SUGGESTIONS.REMOVE_PHOTO') }}
                </span>
              </button>
            </div>
          </div>
        </div>

        <div class="flex justify-end gap-3 mt-2">
          <button
            type="button"
            class="rounded-xl border border-n-container px-4 py-2 text-sm font-medium text-n-slate-11 hover:bg-n-alpha-1"
            @click="emit('close')"
          >
            {{ t('SUGGESTIONS.CANCEL') }}
          </button>
          <button
            type="submit"
            :disabled="submitDisabled"
            class="rounded-xl bg-woot-500 px-4 py-2 text-sm font-medium text-white hover:bg-woot-600 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ submitLabel }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
