<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

const emit = defineEmits(['close', 'created']);
const { t } = useI18n();
const store = useStore();
const title = ref('');
const description = ref('');

const isCreating = computed(
  () => store.getters['suggestions/getUIFlags'].isCreating
);

const isValid = computed(() => title.value.trim().length > 0);

const onSubmit = async () => {
  if (!isValid.value) return;
  try {
    await store.dispatch('suggestions/create', {
      title: title.value.trim(),
      description: description.value.trim(),
    });
    useAlert(t('SUGGESTIONS.CREATE_SUCCESS'));
    emit('created');
  } catch {
    useAlert(t('SUGGESTIONS.CREATE_ERROR'));
  }
};
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50"
    @click.self="emit('close')"
  >
    <div
      class="w-full max-w-lg rounded-2xl bg-white p-6 shadow-xl dark:bg-slate-800"
    >
      <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100 mb-4">
        {{ t('SUGGESTIONS.CREATE_TITLE') }}
      </h2>

      <form class="flex flex-col gap-4" @submit.prevent="onSubmit">
        <div>
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            {{ t('SUGGESTIONS.FIELD_TITLE') }}
          </label>
          <input
            v-model="title"
            type="text"
            :placeholder="t('SUGGESTIONS.FIELD_TITLE_PLACEHOLDER')"
            class="w-full rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm text-slate-700 dark:border-slate-600 dark:bg-slate-700 dark:text-slate-200"
          />
        </div>

        <div>
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            {{ t('SUGGESTIONS.FIELD_DESCRIPTION') }}
          </label>
          <textarea
            v-model="description"
            rows="4"
            :placeholder="t('SUGGESTIONS.FIELD_DESCRIPTION_PLACEHOLDER')"
            class="w-full rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm text-slate-700 dark:border-slate-600 dark:bg-slate-700 dark:text-slate-200 resize-none"
          />
        </div>

        <div class="flex justify-end gap-3 mt-2">
          <button
            type="button"
            class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50 dark:border-slate-600 dark:text-slate-300 dark:hover:bg-slate-700"
            @click="emit('close')"
          >
            {{ t('SUGGESTIONS.CANCEL') }}
          </button>
          <button
            type="submit"
            :disabled="!isValid || isCreating"
            class="rounded-xl bg-woot-500 px-4 py-2 text-sm font-medium text-white hover:bg-woot-600 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ t('SUGGESTIONS.SUBMIT') }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
