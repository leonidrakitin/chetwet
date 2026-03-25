<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from '../../components-next/icon/Icon.vue';

defineProps({
  content: {
    type: String,
    required: true,
  },
  reasoning: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();
const isReasoningExpanded = ref(false);
</script>

<template>
  <div
    class="flex flex-col gap-2 p-3 rounded-lg bg-n-background/50 border border-n-weak hover:bg-n-background/80 transition-colors duration-200"
  >
    <div class="flex items-start gap-2">
      <Icon
        icon="i-lucide-sparkles"
        class="w-4 h-4 mt-0.5 flex-shrink-0 text-n-slate-9"
      />
      <div class="text-sm text-n-slate-12">
        {{ content }}
      </div>
    </div>
    <div v-if="reasoning" class="ml-6">
      <button
        class="flex items-center gap-1 text-xs text-n-slate-9 hover:text-n-slate-11 transition-colors"
        @click="isReasoningExpanded = !isReasoningExpanded"
      >
        <Icon
          :icon="
            isReasoningExpanded
              ? 'i-lucide-chevron-down'
              : 'i-lucide-chevron-right'
          "
          class="w-3 h-3"
        />
        {{ t('CAPTAIN.COPILOT.REASONING') }}
      </button>
      <div
        v-show="isReasoningExpanded"
        class="mt-1 text-xs text-n-slate-10 whitespace-pre-wrap leading-relaxed"
      >
        {{ reasoning }}
      </div>
    </div>
  </div>
</template>
