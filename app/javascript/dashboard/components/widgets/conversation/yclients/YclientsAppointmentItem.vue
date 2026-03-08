<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  record: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

const serviceName = computed(() => {
  const services = props.record.services || [];
  return (
    services.map(s => s.title).join(', ') ||
    t('CONVERSATION_SIDEBAR.YCLIENTS.NO_SERVICE')
  );
});

const staffName = computed(() => {
  return props.record.staff?.name || '';
});

const recordDate = computed(() => {
  const rawDate = props.record.datetime || props.record.date;
  if (!rawDate) return '';

  const parsedDate = new Date(rawDate);
  if (Number.isNaN(parsedDate.getTime())) return rawDate;

  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: props.record.datetime ? 'short' : undefined,
  }).format(parsedDate);
});

const statusLabel = computed(() => {
  const attendance = props.record.attendance;
  switch (Number(attendance)) {
    case 1:
      return t('CONVERSATION_SIDEBAR.YCLIENTS.STATUS_VISITED');
    case 2:
      return t('CONVERSATION_SIDEBAR.YCLIENTS.STATUS_CONFIRMED');
    case -1:
      return t('CONVERSATION_SIDEBAR.YCLIENTS.STATUS_CANCELLED');
    default:
      return t('CONVERSATION_SIDEBAR.YCLIENTS.STATUS_PENDING');
  }
});

const statusClass = computed(() => {
  const attendance = Number(props.record.attendance);
  if (attendance === 1) return 'bg-n-teal-5 text-n-teal-12';
  if (attendance === -1) return 'bg-n-ruby-5 text-n-ruby-12';
  if (attendance === 2) return 'bg-n-blue-5 text-n-blue-12';
  return 'bg-n-solid-3 text-n-slate-12';
});

const companyLabel = computed(() => {
  if (!props.record.company_id) return '';

  return t('CONVERSATION_SIDEBAR.YCLIENTS.COMPANY', {
    id: props.record.company_id,
  });
});
</script>

<template>
  <div
    class="py-3 border-b border-n-weak last:border-b-0 flex flex-col gap-1.5"
  >
    <div class="flex justify-between items-center">
      <div class="font-medium text-n-slate-12 truncate">
        {{ serviceName }}
      </div>
      <div
        :class="statusClass"
        class="text-xs px-2 py-1 rounded capitalize truncate"
      >
        {{ statusLabel }}
      </div>
    </div>
    <div class="text-sm text-n-slate-11">
      <span v-if="recordDate" class="border-r border-n-weak pr-2">
        {{ recordDate }}
      </span>
      <span v-if="staffName" class="pl-2">
        {{ staffName }}
      </span>
    </div>
    <div v-if="companyLabel" class="text-xs text-n-slate-10">
      {{ companyLabel }}
    </div>
  </div>
</template>
