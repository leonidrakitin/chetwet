<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  dayLabel: { type: String, required: true },
  dayConfig: { type: Object, default: () => ({ enabled: false, slots: [] }) },
});

const emit = defineEmits(['update']);

const { t } = useI18n();

const isEnabled = computed(() => props.dayConfig.enabled);
const slots = computed(() => props.dayConfig.slots || []);

const toggleEnabled = () => {
  emit('update', {
    ...props.dayConfig,
    enabled: !isEnabled.value,
    slots: !isEnabled.value ? [{ start: '09:00', end: '18:00' }] : [],
  });
};

const addSlot = () => {
  emit('update', {
    ...props.dayConfig,
    slots: [...slots.value, { start: '09:00', end: '18:00' }],
  });
};

const removeSlot = index => {
  const newSlots = slots.value.filter((_, i) => i !== index);
  emit('update', {
    ...props.dayConfig,
    slots: newSlots,
  });
};

const updateSlot = (index, field, value) => {
  const newSlots = slots.value.map((slot, i) =>
    i === index ? { ...slot, [field]: value } : slot
  );
  emit('update', {
    ...props.dayConfig,
    slots: newSlots,
  });
};
</script>

<template>
  <div
    class="flex items-center gap-3 px-3 py-2 border-b border-n-weak last:border-b-0"
    :class="{ 'bg-n-solid-2': !isEnabled }"
  >
    <button
      class="w-10 text-sm font-medium transition-colors"
      :class="isEnabled ? 'text-n-brand' : 'text-n-slate-10'"
      @click="toggleEnabled"
    >
      {{ dayLabel }}
    </button>

    <div v-if="isEnabled" class="flex flex-1 flex-col gap-2">
      <div
        v-for="(slot, index) in slots"
        :key="index"
        class="flex items-center gap-2"
      >
        <input
          type="time"
          :value="slot.start"
          class="px-2 py-1 text-sm border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
          @change="updateSlot(index, 'start', $event.target.value)"
        />
        <span class="text-n-slate-10">—</span>
        <input
          type="time"
          :value="slot.end"
          class="px-2 py-1 text-sm border border-n-weak rounded-md bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
          @change="updateSlot(index, 'end', $event.target.value)"
        />
        <Button
          v-if="slots.length > 1"
          icon="i-lucide-x"
          slate
          xs
          @click="removeSlot(index)"
        />
      </div>
      <Button
        icon="i-lucide-plus"
        :label="t('SCHEDULE.SETTINGS.ADD_SLOT')"
        faded
        slate
        xs
        @click="addSlot"
      />
    </div>

    <span v-else class="text-sm text-n-slate-10">
      {{ t('SCHEDULE.SETTINGS.DAY_OFF') }}
    </span>
  </div>
</template>
