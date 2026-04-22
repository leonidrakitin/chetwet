<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { format, isToday, isTomorrow } from 'date-fns';
import { ru } from 'date-fns/locale';

const props = defineProps({
  bookings: { type: Array, default: () => [] },
});

const emit = defineEmits(['bookingClick']);

const { t } = useI18n();

const sortedBookings = computed(() => {
  return [...props.bookings].sort((a, b) => {
    return new Date(a.scheduled_at) - new Date(b.scheduled_at);
  });
});

const upcomingBookings = computed(() => {
  const now = new Date();
  return sortedBookings.value.filter(b => {
    const scheduledAt = new Date(b.scheduled_at);
    return scheduledAt >= now && b.status !== 'cancelled';
  });
});

const pastBookings = computed(() => {
  const now = new Date();
  return sortedBookings.value.filter(b => {
    const scheduledAt = new Date(b.scheduled_at);
    return scheduledAt < now || b.status === 'cancelled';
  });
});

const groupedByDate = computed(() => {
  const groups = {};
  upcomingBookings.value.forEach(booking => {
    const dateKey = format(new Date(booking.scheduled_at), 'yyyy-MM-dd');
    if (!groups[dateKey]) {
      groups[dateKey] = [];
    }
    groups[dateKey].push(booking);
  });
  return groups;
});

const getDateLabel = dateStr => {
  const date = new Date(dateStr);
  if (isToday(date)) {
    return t('SCHEDULE.TODAY');
  }
  if (isTomorrow(date)) {
    return t('SCHEDULE.TOMORROW');
  }
  return format(date, 'd MMMM yyyy', { locale: ru });
};

const dateGroups = computed(() => {
  return Object.entries(groupedByDate.value).map(([date, bookings]) => ({
    date,
    bookings,
    label: getDateLabel(date),
  }));
});

const getStatusColor = status => {
  const colors = {
    pending: 'border-l-yellow-400',
    confirmed: 'border-l-blue-400',
    completed: 'border-l-green-400',
    cancelled: 'border-l-red-400',
  };
  return colors[status] || 'border-l-gray-400';
};

const STATUS_LABEL_KEYS = {
  pending: 'SCHEDULE.STATUS.PENDING',
  confirmed: 'SCHEDULE.STATUS.CONFIRMED',
  completed: 'SCHEDULE.STATUS.COMPLETED',
  cancelled: 'SCHEDULE.STATUS.CANCELLED',
};

const statusLabel = status =>
  t(STATUS_LABEL_KEYS[status] || 'SCHEDULE.STATUS.PENDING');
</script>

<template>
  <div class="flex flex-col w-full">
    <div
      v-if="upcomingBookings.length === 0"
      class="flex-1 flex items-center justify-center"
    >
      <div class="text-center text-n-slate-10">
        <p class="text-lg font-medium">{{ t('BOOKINGS.NO_BOOKINGS') }}</p>
        <p class="text-sm mt-1">{{ t('SCHEDULE.NO_UPCOMING') }}</p>
      </div>
    </div>

    <div v-else class="divide-y divide-n-weak">
      <div v-for="group in dateGroups" :key="group.date" class="p-4">
        <h3 class="text-sm font-semibold text-n-slate-12 mb-3">
          {{ group.label }}
        </h3>

        <div class="space-y-2">
          <div
            v-for="booking in group.bookings"
            :key="booking.id"
            class="p-3 bg-n-solid-1 rounded-lg border border-n-weak border-l-4 cursor-pointer hover:bg-n-solid-2 transition-colors"
            :class="getStatusColor(booking.status)"
            @click="emit('bookingClick', booking)"
          >
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <div class="flex items-center gap-2">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ format(new Date(booking.scheduled_at), 'HH:mm') }}
                  </span>
                  <span
                    class="text-xs px-1.5 py-0.5 rounded"
                    :class="{
                      'bg-yellow-100 text-yellow-800':
                        booking.status === 'pending',
                      'bg-blue-100 text-blue-800':
                        booking.status === 'confirmed',
                      'bg-green-100 text-green-800':
                        booking.status === 'completed',
                      'bg-red-100 text-red-800': booking.status === 'cancelled',
                    }"
                  >
                    {{ statusLabel(booking.status) }}
                  </span>
                </div>
                <p class="text-sm text-n-slate-12 mt-1">
                  {{ booking.contact?.name || t('SCHEDULE.NO_CONTACT') }}
                </p>
                <p class="text-xs text-n-slate-10 mt-0.5">
                  {{ booking.service_provider?.name || '' }}
                  <span
                    v-if="booking.services?.length"
                    class="before:content-['•'] before:mr-1"
                  >
                    {{ booking.services.map(s => s.name).join(', ') }}
                  </span>
                </p>
              </div>
              <div class="text-right">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ booking.total_duration_minutes }}
                  {{ t('SCHEDULE.SETTINGS.MINUTES') }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div
      v-if="pastBookings.length > 0"
      class="mt-4 border-t border-n-weak pt-4"
    >
      <h3 class="px-4 text-sm font-semibold text-n-slate-10 mb-3">
        {{ t('BOOKINGS.PAST') }}
      </h3>
      <div class="space-y-2 px-4 pb-4">
        <div
          v-for="booking in pastBookings.slice(0, 5)"
          :key="booking.id"
          class="p-3 bg-n-solid-2 rounded-lg opacity-60"
        >
          <div class="flex items-center justify-between">
            <div>
              <span class="text-sm text-n-slate-11">
                {{ format(new Date(booking.scheduled_at), 'd MMM, HH:mm') }}
              </span>
              <p class="text-sm text-n-slate-10">
                {{ booking.contact?.name || t('SCHEDULE.NO_CONTACT') }}
              </p>
            </div>
            <span
              class="text-xs px-1.5 py-0.5 rounded"
              :class="{
                'bg-red-100 text-red-800': booking.status === 'cancelled',
                'bg-green-100 text-green-800': booking.status === 'completed',
              }"
            >
              {{ statusLabel(booking.status) }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
