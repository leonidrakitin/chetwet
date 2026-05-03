<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  record: {
    type: Object,
    required: true,
  },
  updating: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['updateStatus']);

const { t } = useI18n();
const showDropdown = ref(false);

const statusOptions = computed(() => [
  {
    attendance: 2,
    label: t('CONVERSATION_SIDEBAR.YCLIENTS.STATUS_CONFIRMED'),
    classes: 'bg-n-blue-5 text-n-blue-12',
  },
  {
    attendance: 1,
    label: t('CONVERSATION_SIDEBAR.YCLIENTS.STATUS_VISITED'),
    classes: 'bg-n-teal-5 text-n-teal-12',
  },
  {
    attendance: -1,
    label: t('CONVERSATION_SIDEBAR.YCLIENTS.STATUS_CANCELLED'),
    classes: 'bg-n-ruby-5 text-n-ruby-12',
  },
  {
    attendance: 0,
    label: t('CONVERSATION_SIDEBAR.YCLIENTS.STATUS_PENDING'),
    classes: 'bg-n-solid-3 text-n-text-display',
  },
]);

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

const currentAttendance = computed(() => Number(props.record.attendance));

const statusLabel = computed(() => {
  switch (currentAttendance.value) {
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
  if (currentAttendance.value === 1) return 'bg-n-teal-5 text-n-teal-12';
  if (currentAttendance.value === -1) return 'bg-n-ruby-5 text-n-ruby-12';
  if (currentAttendance.value === 2) return 'bg-n-blue-5 text-n-blue-12';
  return 'bg-n-solid-3 text-n-text-display';
});

const companyLabel = computed(() => {
  if (!props.record.company_id) return '';

  return t('CONVERSATION_SIDEBAR.YCLIENTS.COMPANY', {
    id: props.record.company_id,
  });
});

const toggleDropdown = () => {
  if (!props.updating) {
    showDropdown.value = !showDropdown.value;
  }
};

const closeDropdown = () => {
  showDropdown.value = false;
};

const selectStatus = attendance => {
  if (attendance === currentAttendance.value) {
    closeDropdown();
    return;
  }
  emit('updateStatus', {
    visitId: props.record.visit_id,
    recordId: props.record.id,
    attendance,
    companyId: props.record.company_id,
  });
  closeDropdown();
};
</script>

<template>
  <div
    class="py-3 border-b border-n-border-glass-soft last:border-b-0 flex flex-col gap-1.5"
  >
    <div class="flex justify-between items-center">
      <div class="font-medium text-n-text-display truncate">
        {{ serviceName }}
      </div>
      <div v-on-click-outside="closeDropdown" class="relative">
        <button
          class="text-xs px-2 py-1 rounded capitalize truncate cursor-pointer flex items-center gap-1"
          :class="statusClass"
          :title="t('CONVERSATION_SIDEBAR.YCLIENTS.UPDATE_STATUS')"
          @click="toggleDropdown"
        >
          <Spinner v-if="updating" size="12" />
          <span>{{ statusLabel }}</span>
        </button>
        <div
          v-if="showDropdown"
          class="absolute right-0 top-full mt-1 z-50 min-w-[140px] rounded-lg border border-n-border-glass-soft bg-n-glass-strong py-1 shadow-lg"
        >
          <button
            v-for="option in statusOptions"
            :key="option.attendance"
            class="flex w-full items-center gap-2 px-3 py-1.5 text-xs text-n-text-display hover:bg-n-alpha-1"
            :class="{
              'font-semibold': option.attendance === currentAttendance,
            }"
            @click="selectStatus(option.attendance)"
          >
            <span
              class="inline-block h-2 w-2 rounded-full"
              :class="option.classes"
            />
            {{ option.label }}
          </button>
        </div>
      </div>
    </div>
    <div class="text-sm text-n-text-body">
      <span v-if="recordDate" class="border-r border-n-border-glass-soft pr-2">
        {{ recordDate }}
      </span>
      <span v-if="staffName" class="pl-2">
        {{ staffName }}
      </span>
    </div>
    <div v-if="companyLabel" class="text-xs text-n-text-body/60">
      {{ companyLabel }}
    </div>
  </div>
</template>
