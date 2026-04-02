<script setup>
import { computed } from 'vue';
import { useToggle } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { usePolicy } from 'dashboard/composables/usePolicy';
import {
  isPdfDocument,
  formatDocumentLink,
} from 'shared/helpers/documentHelper';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  id: {
    type: Number,
    required: true,
  },
  name: {
    type: String,
    default: '',
  },
  assistant: {
    type: Object,
    default: () => ({}),
  },
  externalLink: {
    type: String,
    required: true,
  },
  createdAt: {
    type: Number,
    required: true,
  },
  isSelected: {
    type: Boolean,
    default: false,
  },
  selectable: {
    type: Boolean,
    default: false,
  },
  showSelectionControl: {
    type: Boolean,
    default: false,
  },
  showMenu: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['action', 'select', 'hover']);
const { checkPermissions } = usePolicy();

const { t } = useI18n();

const [showActionsDropdown, toggleDropdown] = useToggle();
const modelValue = computed({
  get: () => props.isSelected,
  set: () => emit('select', props.id),
});

const menuItems = computed(() => {
  const allOptions = [
    {
      label: t('CAPTAIN.DOCUMENTS.OPTIONS.VIEW_RELATED_RESPONSES'),
      value: 'viewRelatedQuestions',
      action: 'viewRelatedQuestions',
      icon: 'i-ph-tree-view-duotone',
    },
  ];

  if (checkPermissions(['administrator'])) {
    allOptions.push({
      label: t('CAPTAIN.DOCUMENTS.OPTIONS.DELETE_DOCUMENT'),
      value: 'delete',
      action: 'delete',
      icon: 'i-lucide-trash',
    });
  }

  return allOptions;
});

const createdAt = computed(() => dynamicTime(props.createdAt));

const displayLink = computed(() => formatDocumentLink(props.externalLink));
const linkIcon = computed(() =>
  isPdfDocument(props.externalLink) ? 'i-ph-file-pdf' : 'i-ph-link-simple'
);

const handleAction = ({ action, value }) => {
  toggleDropdown(false);
  emit('action', { action, value, id: props.id });
};
</script>

<template>
  <CardLayout
    :selectable="selectable"
    class="relative"
    @mouseenter="emit('hover', true)"
    @mouseleave="emit('hover', false)"
  >
    <div
      v-show="showSelectionControl"
      class="absolute top-7 ltr:left-3 rtl:right-3"
    >
      <Checkbox v-model="modelValue" />
    </div>
    <div class="flex gap-4 w-full items-start">
      <div
        class="shrink-0 size-10 rounded-lg flex items-center justify-center"
        :class="
          isPdfDocument(externalLink)
            ? 'bg-n-ruby-3 text-n-ruby-11'
            : 'bg-n-iris-3 text-n-iris-11'
        "
      >
        <i :class="linkIcon" class="size-5" />
      </div>
      <div class="flex flex-col min-w-0 flex-1 gap-1">
        <div class="flex gap-1 justify-between w-full items-start">
          <span
            class="text-sm font-medium text-n-slate-12 line-clamp-2 leading-snug"
          >
            {{ name }}
          </span>
          <div v-if="showMenu" class="shrink-0 flex gap-2 items-center">
            <div
              v-on-clickaway="() => toggleDropdown(false)"
              class="flex relative items-center group"
            >
              <Button
                icon="i-lucide-ellipsis-vertical"
                color="slate"
                size="xs"
                class="rounded-md group-hover:bg-n-alpha-2"
                @click="toggleDropdown()"
              />
              <DropdownMenu
                v-if="showActionsDropdown"
                :menu-items="menuItems"
                class="top-full mt-1 ltr:right-0 rtl:left-0 xl:ltr:right-0 xl:rtl:left-0"
                @action="handleAction($event)"
              />
            </div>
          </div>
        </div>
        <div class="flex gap-3 items-center flex-wrap">
          <span class="flex gap-1 items-center text-xs text-n-slate-10">
            <i class="i-woot-captain size-3" />
            {{ assistant?.name || '' }}
          </span>
          <span class="flex gap-1 items-center text-xs text-n-slate-10 min-w-0">
            <i :class="linkIcon" class="shrink-0 size-3" />
            <span class="truncate">{{ displayLink }}</span>
          </span>
          <span class="text-xs text-n-slate-9 ml-auto">
            {{ createdAt }}
          </span>
        </div>
      </div>
    </div>
  </CardLayout>
</template>
