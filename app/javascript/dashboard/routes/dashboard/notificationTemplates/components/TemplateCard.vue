<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  template: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['toggle', 'edit', 'delete', 'clone', 'preview']);

const { t } = useI18n();
const menuOpen = ref(false);

const toggleMenu = () => {
  menuOpen.value = !menuOpen.value;
};

const closeMenu = () => {
  menuOpen.value = false;
};

const handleToggle = () => {
  emit('toggle', props.template.id);
};

const handlePreview = () => {
  closeMenu();
  emit('preview', props.template);
};

const handleEdit = () => {
  closeMenu();
  emit('edit', props.template);
};

const handleClone = () => {
  closeMenu();
  emit('clone', props.template.id);
};

const handleDelete = () => {
  closeMenu();
  emit('delete', props.template);
};

const eventLabel = template => {
  if (template.type === 'event' && template.triggerEvent) {
    return t(`NOTIFICATION_TEMPLATES.EVENTS.${template.triggerEvent}`);
  }
  if (template.type === 'time') {
    const offset = template.timeOffset ?? '';
    const unit = t(
      `NOTIFICATION_TEMPLATES.TIME_UNIT.${template.timeUnit ?? 'HOURS'}`
    );
    const dir = t(
      `NOTIFICATION_TEMPLATES.TIME_DIRECTION.${template.timeDirection ?? 'BEFORE'}`
    );
    return `${offset} ${unit} ${dir}`;
  }
  return t(`NOTIFICATION_TEMPLATES.TYPES.${template.type.toUpperCase()}`);
};
</script>

<template>
  <div
    class="relative flex flex-col gap-3 p-4 rounded-xl border border-n-weak bg-n-solid-1 hover:border-n-strong transition-colors duration-200"
  >
    <div class="flex items-center justify-between gap-2">
      <div class="flex items-center gap-2">
        <Switch :model-value="template.enabled" @change="handleToggle" />
        <span class="text-xs text-n-slate-10 font-mono">
          #{{ template.id }}
        </span>
      </div>
      <OnClickOutside @trigger="closeMenu">
        <div class="relative">
          <Button
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-ellipsis"
            @click="toggleMenu"
          />
          <div
            v-if="menuOpen"
            class="absolute right-0 top-8 z-50 min-w-36 rounded-lg border border-n-weak bg-n-solid-1 shadow-lg py-1"
          >
            <button
              class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-slate-12 hover:bg-n-alpha-1 transition-colors"
              @click="handlePreview"
            >
              <span class="i-lucide-eye size-4 text-n-slate-10" />
              {{ t('NOTIFICATION_TEMPLATES.PREVIEW.BUTTON_TEXT') }}
            </button>
            <button
              class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-slate-12 hover:bg-n-alpha-1 transition-colors"
              @click="handleEdit"
            >
              <span class="i-lucide-pencil size-4 text-n-slate-10" />
              {{ t('NOTIFICATION_TEMPLATES.EDIT.BUTTON_TEXT') }}
            </button>
            <button
              class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-slate-12 hover:bg-n-alpha-1 transition-colors"
              @click="handleClone"
            >
              <span class="i-lucide-copy size-4 text-n-slate-10" />
              {{ t('NOTIFICATION_TEMPLATES.CLONE.BUTTON_TEXT') }}
            </button>
            <button
              class="flex w-full items-center gap-2 px-3 py-2 text-sm text-n-ruby-11 hover:bg-n-alpha-1 transition-colors"
              @click="handleDelete"
            >
              <span class="i-lucide-trash-2 size-4" />
              {{ t('NOTIFICATION_TEMPLATES.DELETE.BUTTON_TEXT') }}
            </button>
          </div>
        </div>
      </OnClickOutside>
    </div>

    <div class="flex flex-col gap-1">
      <h3 class="text-sm font-semibold text-n-slate-12 leading-snug">
        {{ template.name }}
      </h3>
      <p class="text-xs text-n-slate-10 line-clamp-2 leading-relaxed">
        {{ template.messageText }}
      </p>
    </div>

    <div class="flex items-center">
      <span
        class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium bg-n-brand/10 text-n-blue-11"
      >
        {{ eventLabel(template) }}
      </span>
    </div>
  </div>
</template>
