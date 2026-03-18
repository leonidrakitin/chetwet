<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

defineProps({
  category: { type: Object, required: true },
  templates: { type: Array, default: () => [] },
});

defineEmits(['toggle', 'edit']);

const { t } = useI18n();
const collapsed = ref(false);

const toggle = () => {
  collapsed.value = !collapsed.value;
};
</script>

<template>
  <div class="rounded-xl border border-n-weak bg-n-solid-1 overflow-hidden">
    <!-- Category header -->
    <button
      class="flex items-center gap-3 w-full px-4 py-3 hover:bg-n-alpha-1 transition-colors"
      @click="toggle"
    >
      <div
        class="flex items-center justify-center size-9 rounded-lg flex-shrink-0"
        :class="category.bgColor"
      >
        <span class="size-5" :class="[category.icon, category.color]" />
      </div>
      <div class="flex flex-col items-start min-w-0 flex-1">
        <span class="text-sm font-semibold text-n-slate-12 truncate">
          {{
            t(
              `NOTIFICATION_TEMPLATES.CATEGORIES.${category.key.toUpperCase()}.TITLE`
            )
          }}
        </span>
        <span class="text-xs text-n-slate-10">
          {{
            t(
              `NOTIFICATION_TEMPLATES.CATEGORIES.${category.key.toUpperCase()}.DESCRIPTION`
            )
          }}
        </span>
      </div>
      <span class="text-xs text-n-slate-9 flex-shrink-0 tabular-nums">
        {{ templates.length }}
      </span>
      <span
        class="i-lucide-chevron-down size-4 text-n-slate-9 flex-shrink-0 transition-transform duration-200"
        :class="{ '-rotate-90': collapsed }"
      />
    </button>

    <!-- Template list -->
    <div
      v-show="!collapsed"
      class="border-t border-n-weak divide-y divide-n-weak"
    >
      <div
        v-for="tmpl in templates"
        :key="tmpl.id"
        class="flex items-center gap-3 px-4 py-3 hover:bg-n-alpha-1 transition-colors group"
      >
        <!-- Template icon -->
        <div
          class="flex items-center justify-center size-8 rounded-lg bg-n-alpha-1 flex-shrink-0"
        >
          <span class="size-4 text-n-slate-10" :class="tmpl.icon" />
        </div>

        <!-- Name + description -->
        <button
          class="flex flex-col items-start min-w-0 flex-1 text-left"
          @click="$emit('edit', tmpl)"
        >
          <span class="text-sm font-medium text-n-slate-12 truncate max-w-full">
            {{ tmpl.name }}
          </span>
          <span
            v-if="tmpl.description"
            class="text-xs text-n-slate-10 truncate max-w-full"
          >
            {{ tmpl.description }}
          </span>
        </button>

        <!-- Enable/Disable toggle -->
        <button
          class="relative inline-flex h-5 w-9 flex-shrink-0 cursor-pointer items-center rounded-full transition-colors duration-200"
          :class="tmpl.enabled ? 'bg-n-teal-9' : 'bg-n-slate-7'"
          role="switch"
          :aria-checked="tmpl.enabled"
          :title="
            tmpl.enabled
              ? t('NOTIFICATION_TEMPLATES.TOGGLE.DISABLE')
              : t('NOTIFICATION_TEMPLATES.TOGGLE.ENABLE')
          "
          @click.stop="$emit('toggle', tmpl)"
        >
          <span
            class="inline-block size-3.5 rounded-full bg-white shadow transition-transform duration-200"
            :class="tmpl.enabled ? 'translate-x-[18px]' : 'translate-x-[3px]'"
          />
        </button>
      </div>

      <!-- Empty state for 'yours' category -->
      <div
        v-if="templates.length === 0"
        class="flex items-center justify-center py-6 text-sm text-n-slate-9"
      >
        {{ t('NOTIFICATION_TEMPLATES.CATEGORIES.YOURS.EMPTY') }}
      </div>
    </div>
  </div>
</template>
