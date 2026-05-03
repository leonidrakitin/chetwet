<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, minValue } from '@vuelidate/validators';

import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  selectedService: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close']);
const store = useStore();
const { t } = useI18n();

const name = ref(props.selectedService.name || '');
const description = ref(props.selectedService.description || '');
const durationMinutes = ref(props.selectedService.duration_minutes || 30);
const price = ref(props.selectedService.price || null);
const currency = ref(props.selectedService.currency || 'RUB');
const active = ref(props.selectedService.active ?? true);

const rules = {
  name: { required, minLength: minLength(2) },
  durationMinutes: { required, minValue: minValue(5) },
};

const v$ = useVuelidate(rules, { name, durationMinutes });

const uiFlags = computed(() => store.getters['services/getUIFlags']);
const isUpdating = computed(() => uiFlags.value.isUpdatingService);

const onClose = () => {
  emit('close');
};

const updateService = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    await store.dispatch('services/updateService', {
      id: props.selectedService.id,
      name: name.value,
      description: description.value,
      duration_minutes: parseInt(durationMinutes.value, 10),
      price: price.value ? parseFloat(price.value) : null,
      currency: currency.value,
      active: active.value,
    });
    useAlert(t('SERVICES_MGMT.SERVICES.EDIT.API.SUCCESS_MESSAGE'));
    onClose();
  } catch (error) {
    const errorMessage =
      error?.message || t('SERVICES_MGMT.SERVICES.EDIT.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('SERVICES_MGMT.SERVICES.EDIT.TITLE')"
      :header-content="$t('SERVICES_MGMT.SERVICES.EDIT.DESC')"
    />
    <form class="flex flex-wrap mx-0" @submit.prevent="updateService">
      <woot-input
        v-model="name"
        :class="{ error: v$.name.$error }"
        class="w-full"
        :label="$t('SERVICES_MGMT.FORM.NAME.LABEL')"
        :placeholder="$t('SERVICES_MGMT.FORM.NAME.PLACEHOLDER')"
        :error="
          v$.name.$error ? $t('SERVICES_MGMT.FORM.NAME.REQUIRED_ERROR') : ''
        "
        @input="v$.name.$touch"
        @blur="v$.name.$touch"
      />

      <woot-input
        v-model="description"
        class="w-full"
        :label="$t('SERVICES_MGMT.FORM.DESCRIPTION.LABEL')"
        :placeholder="$t('SERVICES_MGMT.FORM.DESCRIPTION.PLACEHOLDER')"
      />

      <div class="flex gap-4 w-full">
        <woot-input
          v-model="durationMinutes"
          :class="{ error: v$.durationMinutes.$error }"
          type="number"
          class="flex-1"
          :label="$t('SERVICES_MGMT.FORM.DURATION.LABEL')"
          :placeholder="$t('SERVICES_MGMT.FORM.DURATION.PLACEHOLDER')"
          :error="
            v$.durationMinutes.$error
              ? $t('SERVICES_MGMT.FORM.DURATION.REQUIRED_ERROR')
              : ''
          "
          @input="v$.durationMinutes.$touch"
        />

        <woot-input
          v-model="price"
          type="number"
          step="0.01"
          class="flex-1"
          :label="$t('SERVICES_MGMT.FORM.PRICE.LABEL')"
          :placeholder="$t('SERVICES_MGMT.FORM.PRICE.PLACEHOLDER')"
        />
      </div>

      <woot-input
        v-model="currency"
        class="w-full"
        :label="$t('SERVICES_MGMT.FORM.CURRENCY.LABEL')"
        :placeholder="$t('SERVICES_MGMT.FORM.CURRENCY.PLACEHOLDER')"
      />

      <div class="w-full mb-4">
        <label class="text-sm font-medium text-n-text-display">
          {{ $t('SERVICES_MGMT.FORM.STATUS.LABEL') }}
        </label>
        <div class="flex items-center gap-2 mt-2">
          <input
            v-model="active"
            type="checkbox"
            class="w-4 h-4 rounded border-n-border-glass-soft-stroke"
          />
          <span class="text-sm text-n-text-body">
            {{ $t('SERVICES_MGMT.FORM.STATUS.ACTIVE') }}
          </span>
        </div>
      </div>

      <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
        <NextButton
          faded
          slate
          type="reset"
          :label="$t('SERVICES_MGMT.FORM.CANCEL')"
          @click.prevent="onClose"
        />
        <NextButton
          type="submit"
          :label="$t('SERVICES_MGMT.FORM.UPDATE')"
          :disabled="v$.$invalid || isUpdating"
          :is-loading="isUpdating"
        />
      </div>
    </form>
  </div>
</template>
