<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import YclientsAPI from '../../../../api/integrations/yclients';
import YclientsAppointmentItem from './YclientsAppointmentItem.vue';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
  integrationEnabled: {
    type: Boolean,
    default: false,
  },
  settingsPath: {
    type: String,
    default: '',
  },
});

const records = ref([]);
const transactions = ref([]);
const loading = ref(true);
const refreshing = ref(false);
const errorMessage = ref('');
const { t } = useI18n();
const hasLoadError = computed(() => Boolean(errorMessage.value));
const loadErrorText = computed(() =>
  errorMessage.value === 'CONVERSATION_SIDEBAR.YCLIENTS.ERROR'
    ? t('CONVERSATION_SIDEBAR.YCLIENTS.ERROR')
    : errorMessage.value
);

const hasData = computed(
  () => records.value.length > 0 || transactions.value.length > 0
);

const fetchYclientsData = async () => {
  if (!props.integrationEnabled) {
    records.value = [];
    transactions.value = [];
    loading.value = false;
    errorMessage.value = '';
    return;
  }

  try {
    if (loading.value) {
      loading.value = true;
    } else {
      refreshing.value = true;
    }
    errorMessage.value = '';
    const [recordsResponse, financesResponse] = await Promise.all([
      YclientsAPI.getRecords(props.contactId),
      YclientsAPI.getFinances(props.contactId),
    ]);
    records.value = recordsResponse.data.records || [];
    transactions.value = financesResponse.data.transactions || [];
  } catch (e) {
    errorMessage.value =
      e.response?.data?.error || 'CONVERSATION_SIDEBAR.YCLIENTS.ERROR';
  } finally {
    loading.value = false;
    refreshing.value = false;
  }
};

watch(
  () => [props.contactId, props.integrationEnabled],
  () => {
    loading.value = true;
    fetchYclientsData();
  },
  { immediate: true }
);
</script>

<template>
  <div class="px-4 py-2 text-n-slate-12">
    <div
      v-if="!integrationEnabled"
      class="flex flex-col gap-3 rounded-lg border border-n-weak bg-n-alpha-1 p-3"
    >
      <p class="text-sm text-n-slate-11">
        {{ $t('CONVERSATION_SIDEBAR.YCLIENTS.NOT_CONNECTED') }}
      </p>
      <a
        v-if="settingsPath"
        :href="settingsPath"
        class="text-sm font-medium text-n-brand hover:underline"
      >
        {{ $t('CONVERSATION_SIDEBAR.YCLIENTS.CONNECT_CTA') }}
      </a>
    </div>
    <div v-if="loading" class="flex justify-center items-center p-4">
      <Spinner size="32" class="text-n-brand" />
    </div>
    <div v-else-if="hasLoadError" class="text-center text-n-ruby-12 text-sm">
      {{ loadErrorText }}
    </div>
    <div v-else>
      <div class="flex justify-end pb-2">
        <NextButton
          faded
          slate
          sm
          :label="$t('CONVERSATION_SIDEBAR.YCLIENTS.REFRESH')"
          :is-loading="refreshing"
          @click="fetchYclientsData"
        />
      </div>
      <div v-if="records.length" class="pb-3">
        <p
          class="pb-2 text-xs font-medium uppercase tracking-wide text-n-slate-10"
        >
          {{ $t('CONVERSATION_SIDEBAR.YCLIENTS.APPOINTMENTS_SECTION') }}
        </p>
        <YclientsAppointmentItem
          v-for="record in records"
          :key="`${record.company_id || 'default'}-${record.id}`"
          :record="record"
        />
      </div>
      <div v-if="transactions.length" class="flex flex-col gap-2 pt-1">
        <p class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
          {{ $t('CONVERSATION_SIDEBAR.YCLIENTS.TRANSACTIONS_SECTION') }}
        </p>
        <div
          v-for="transaction in transactions"
          :key="`${transaction.company_id || 'default'}-${transaction.record_id}-${transaction.title}-${transaction.amount}`"
          class="rounded-lg border border-n-weak px-3 py-2"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
              <p class="truncate text-sm font-medium text-n-slate-12">
                {{
                  transaction.title ||
                  $t('CONVERSATION_SIDEBAR.YCLIENTS.PAYMENT')
                }}
              </p>
              <p class="text-xs text-n-slate-10">
                {{ transaction.date }}
              </p>
            </div>
            <div class="text-right text-sm font-medium text-n-slate-12">
              {{ transaction.total ?? transaction.amount }}
            </div>
          </div>
          <div class="pt-1 text-xs text-n-slate-10">
            <span v-if="transaction.company_id">
              {{
                $t('CONVERSATION_SIDEBAR.YCLIENTS.COMPANY', {
                  id: transaction.company_id,
                })
              }}
            </span>
            <span v-if="transaction.discount">
              {{
                $t('CONVERSATION_SIDEBAR.YCLIENTS.DISCOUNT', {
                  amount: transaction.discount,
                })
              }}
            </span>
          </div>
        </div>
      </div>
      <div v-if="!hasData" class="text-center text-n-slate-11 text-sm">
        {{ $t('CONVERSATION_SIDEBAR.YCLIENTS.NO_APPOINTMENTS') }}
      </div>
    </div>
  </div>
</template>
