<script setup>
import { ref, reactive, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const emit = defineEmits(['close', 'created']);

const { t, locale: i18nLocale } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const selectedTemplate = ref(null);
const form = reactive({ productName: '', locale: 'ru' });

const templates = useMapGetter('captainAssistantTemplates/getRecords');
const uiFlags = useMapGetter('captainAssistantTemplates/getUIFlags');

const isFetching = computed(() => uiFlags.value.fetchingList);
const isCreating = computed(() => uiFlags.value.creatingAssistant);

const industryIcons = {
  restaurant: 'i-lucide-utensils',
  beauty: 'i-lucide-scissors',
  hr: 'i-lucide-user-round-search',
  recruiter: 'i-lucide-user-round-search',
};

const templateIcon = template =>
  industryIcons[template.industry] || 'i-lucide-sparkles';

const resolvedLocale = computed(() =>
  i18nLocale.value?.startsWith('ru') ? 'ru' : 'en'
);

const loadTemplates = () => {
  const locale = resolvedLocale.value;
  form.locale = locale;
  store.dispatch('captainAssistantTemplates/list', { locale });
};

const handleSelect = template => {
  selectedTemplate.value = template;
  form.productName = template.product_name_placeholder || '';
};

const handleBack = () => {
  selectedTemplate.value = null;
};

const canSubmit = computed(
  () => selectedTemplate.value && form.productName.trim().length > 0
);

const handleCreate = async () => {
  if (!canSubmit.value) return;
  try {
    const assistant = await store.dispatch(
      'captainAssistantTemplates/createAssistant',
      {
        templateId: selectedTemplate.value.id,
        productName: form.productName.trim(),
        locale: form.locale,
      }
    );
    useAlert(t('CAPTAIN.ASSISTANTS.TEMPLATES.SUCCESS_MESSAGE'));
    emit('created', assistant);
    dialogRef.value.close();
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.ASSISTANTS.TEMPLATES.ERROR_MESSAGE'));
  }
};

const handleCreateEmpty = async () => {
  if (isCreating.value) return;
  try {
    const defaultName = t('CAPTAIN.ASSISTANTS.TEMPLATES.EMPTY.DEFAULT_NAME');
    const productName = defaultName;
    const assistant = await store.dispatch('captainAssistants/create', {
      name: defaultName,
      description: t('CAPTAIN.ASSISTANTS.TEMPLATES.EMPTY.DEFAULT_DESCRIPTION'),
      config: {
        product_name: productName,
        feature_faq: false,
        feature_memory: false,
        feature_citation: false,
      },
    });
    useAlert(t('CAPTAIN.ASSISTANTS.CREATE.SUCCESS_MESSAGE'));
    emit('created', assistant);
    dialogRef.value.close();
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.ASSISTANTS.CREATE.ERROR_MESSAGE'));
  }
};

const handleClose = () => emit('close');

watch(
  () => i18nLocale.value,
  newLocale => {
    const locale = newLocale?.startsWith('ru') ? 'ru' : 'en';
    if (form.locale !== locale) {
      form.locale = locale;
      store.dispatch('captainAssistantTemplates/list', { locale });
    }
  }
);

const open = () => {
  selectedTemplate.value = null;
  form.productName = '';
  loadTemplates();
  dialogRef.value.open();
};

defineExpose({ open, dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    width="3xl"
    :title="
      selectedTemplate
        ? selectedTemplate.name
        : t('CAPTAIN.ASSISTANTS.TEMPLATES.TITLE')
    "
    :description="
      selectedTemplate
        ? selectedTemplate.description
        : t('CAPTAIN.ASSISTANTS.TEMPLATES.DESCRIPTION')
    "
    :show-cancel-button="false"
    :show-confirm-button="false"
    overflow-y-auto
    @close="handleClose"
  >
    <div
      v-if="isFetching"
      class="flex items-center justify-center py-10 text-n-text-body"
    >
      <Spinner />
    </div>

    <div
      v-else-if="!selectedTemplate"
      class="grid grid-cols-1 md:grid-cols-2 gap-3"
    >
      <button
        v-for="template in templates"
        :key="template.id"
        type="button"
        class="flex flex-col gap-2 p-4 text-start border border-n-border-glass-soft rounded-xl bg-n-glass-soft hover:border-n-blue-9 hover:shadow transition-all disabled:opacity-60 disabled:cursor-not-allowed"
        :disabled="isCreating"
        @click="handleSelect(template)"
      >
        <div class="flex items-center gap-2">
          <Icon :icon="templateIcon(template)" class="size-5 text-n-blue-11" />
          <span class="text-sm font-medium text-n-text-display">
            {{ template.name }}
          </span>
        </div>
        <p class="text-xs text-n-text-body line-clamp-3">
          {{ template.description }}
        </p>
        <div class="flex items-center gap-3 mt-1 text-xs text-n-text-body">
          <span class="flex items-center gap-1">
            <Icon icon="i-lucide-workflow" class="size-3.5" />
            {{
              t('CAPTAIN.ASSISTANTS.TEMPLATES.SCENARIOS_COUNT', {
                count: template.scenarios?.length ?? 0,
              })
            }}
          </span>
          <span class="flex items-center gap-1">
            <Icon icon="i-lucide-message-circle-question" class="size-3.5" />
            {{
              t('CAPTAIN.ASSISTANTS.TEMPLATES.FAQ_COUNT', {
                count: template.faq_count,
              })
            }}
          </span>
        </div>
      </button>

      <button
        type="button"
        class="flex flex-col gap-2 p-4 text-start border border-dashed border-n-border-glass-soft rounded-xl bg-n-alpha-1 hover:border-n-blue-9 hover:bg-n-alpha-2 transition-all disabled:opacity-60 disabled:cursor-not-allowed"
        :disabled="isCreating"
        @click="handleCreateEmpty"
      >
        <div class="flex items-center gap-2">
          <Icon icon="i-lucide-plus" class="size-5 text-n-blue-11" />
          <span class="text-sm font-medium text-n-text-display">
            {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.EMPTY.TITLE') }}
          </span>
        </div>
        <p class="text-xs text-n-text-body line-clamp-3">
          {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.EMPTY.DESCRIPTION') }}
        </p>
      </button>
    </div>

    <div v-else class="flex flex-col gap-5">
      <section>
        <h4
          class="text-xs font-medium uppercase text-n-text-body mb-2 tracking-wide"
        >
          {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.SECTIONS.SCENARIOS') }}
        </h4>
        <ul class="flex flex-col gap-2">
          <li
            v-for="scenario in selectedTemplate.scenarios"
            :key="scenario.key"
            class="p-3 border border-n-border-glass-soft rounded-lg bg-n-alpha-1"
          >
            <div class="text-sm font-medium text-n-text-display">
              {{ scenario.title }}
            </div>
            <div class="text-xs text-n-text-body mt-0.5">
              {{ scenario.description }}
            </div>
          </li>
        </ul>
      </section>

      <section
        v-if="selectedTemplate.documents_seed.length"
        class="flex flex-col gap-2"
      >
        <h4
          class="text-xs font-medium uppercase text-n-text-body tracking-wide"
        >
          {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.SECTIONS.DOCUMENTS_HINT') }}
        </h4>
        <ul class="flex flex-col gap-1 list-disc pl-5">
          <li
            v-for="(doc, index) in selectedTemplate.documents_seed"
            :key="`doc-${index}`"
            class="text-xs text-n-text-body"
          >
            <span class="font-medium text-n-text-display">{{ doc.title }}</span>
            <span v-if="doc.hint" class="block">{{ doc.hint }}</span>
          </li>
        </ul>
      </section>

      <section class="flex flex-col gap-3">
        <Input
          v-model="form.productName"
          :label="t('CAPTAIN.ASSISTANTS.TEMPLATES.FORM.PRODUCT_NAME.LABEL')"
          :placeholder="
            t('CAPTAIN.ASSISTANTS.TEMPLATES.FORM.PRODUCT_NAME.PLACEHOLDER')
          "
        />
        <div class="flex flex-col gap-1.5">
          <label class="text-sm font-medium text-n-text-display">
            {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.FORM.LOCALE.LABEL') }}
          </label>
          <select
            v-model="form.locale"
            class="appearance-none rounded-lg border border-n-border-glass-soft bg-n-glass-soft py-2 px-3 text-sm text-n-text-display"
          >
            <option value="ru">
              {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.FORM.LOCALE.OPTIONS.RU') }}
            </option>
            <option value="en">
              {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.FORM.LOCALE.OPTIONS.EN') }}
            </option>
          </select>
          <p class="text-xs text-n-text-body">
            {{ t('CAPTAIN.ASSISTANTS.TEMPLATES.FORM.LOCALE.HINT') }}
          </p>
        </div>
      </section>
    </div>

    <template #footer>
      <div
        v-if="selectedTemplate"
        class="flex items-center justify-between w-full gap-3"
      >
        <Button
          type="button"
          variant="faded"
          color="slate"
          :label="t('CAPTAIN.ASSISTANTS.TEMPLATES.BUTTONS.BACK')"
          class="w-full"
          @click="handleBack"
        />
        <Button
          type="button"
          :label="t('CAPTAIN.ASSISTANTS.TEMPLATES.BUTTONS.CREATE')"
          class="w-full"
          :is-loading="isCreating"
          :disabled="!canSubmit || isCreating"
          @click="handleCreate"
        />
      </div>
      <div v-else class="flex justify-end">
        <Button
          type="button"
          :label="t('CAPTAIN.ASSISTANTS.TEMPLATES.BUTTONS.CANCEL')"
          class="w-full md:w-auto"
          variant="faded"
          color="slate"
          @click="handleClose"
        />
      </div>
    </template>
  </Dialog>
</template>
