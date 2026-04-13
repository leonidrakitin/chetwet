<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  booking: {
    type: Object,
    required: true,
  },
  isPast: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['cancel']);

const { t } = useI18n();

const statusColors = {
  pending: 'bg-n-amber-5 text-n-amber-12',
  confirmed: 'bg-n-blue-5 text-n-blue-12',
  completed: 'bg-n-teal-5 text-n-teal-12',
  cancelled: 'bg-n-ruby-5 text-n-ruby-12',
};

const statusLabels = {
  pending: t('BOOKINGS.STATUS.PENDING'),
  confirmed: t('BOOKINGS.STATUS.CONFIRMED'),
  completed: t('BOOKINGS.STATUS.COMPLETED'),
  cancelled: t('BOOKINGS.STATUS.CANCELLED'),
};

const serviceName = computed(() => {
  return (
    props.booking.services?.map(s => s.name).join(', ') ||
    t('BOOKINGS.NO_SERVICE')
  );
});

const providerName = computed(() => {
  return props.booking.service_provider?.name || '';
});

const bookingDate = computed(() => {
  const date = new Date(props.booking.scheduled_at);
  return format(date, 'd MMMM yyyy, HH:mm', { locale: ru });
});

const statusClass = computed(() => {
  return statusColors[props.booking.status] || statusColors.pending;
});

const statusLabel = computed(() => {
  return statusLabels[props.booking.status] || props.booking.status;
});

const canCancel = computed(() => {
  return props.booking.status !== 'cancelled' && !props.isPast;
});

const handleCancel = () => {
  emit('cancel', props.booking.id);
};
</script>

<template>
  <div
    class="py-3 border-b border-n-weak last:border-b-0 flex flex-col gap-1.5"
    :class="{ 'opacity-60': isPast }"
  >
    <div class="flex justify-between items-start gap-2">
      <div class="font-medium text-n-slate-12 truncate flex-1">
        {{ serviceName }}
      </div>
      <span
        :class="statusClass"
        class="text-xs px-2 py-0.5 rounded capitalize flex-shrink-0"
      >
        {{ statusLabel }}
      </span>
    </div>

    <div class="text-sm text-n-slate-11">
      <span class="border-r border-n-weak pr-2">
        {{ bookingDate }}
      </span>
      <span v-if="providerName" class="pl-2">
        {{ providerName }}
      </span>
    </div>

    <div v-if="booking.customer_notes" class="text-xs text-n-slate-10 mt-1">
      {{ booking.customer_notes }}
    </div>

    <div v-if="canCancel" class="flex justify-end mt-1">
      <Button
        :label="t('BOOKINGS.CANCEL')"
        size="sm"
        faded
        slate
        class="!text-xs !py-1"
        @click="handleCancel"
      />
    </div>
  </div>
</template>
