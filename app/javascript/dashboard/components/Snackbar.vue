<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';

const props = defineProps({
  message: { type: String, default: '' },
  action: {
    type: Object,
    default: () => ({}),
  },
  duration: { type: Number, default: 3000 },
});

const emit = defineEmits(['dismiss']);

const progressWidth = ref(100);
let animationFrame = null;
let startTime = null;

const variant = computed(() => props.action?.variant || 'info');

const variantConfig = computed(() => {
  const configs = {
    success: {
      icon: 'i-lucide-circle-check',
      iconBg: 'bg-n-teal-3',
      iconColor: 'text-n-teal-11',
      progressColor: 'bg-n-teal-9',
    },
    error: {
      icon: 'i-lucide-circle-x',
      iconBg: 'bg-n-ruby-3',
      iconColor: 'text-n-ruby-11',
      progressColor: 'bg-n-ruby-9',
    },
    warning: {
      icon: 'i-lucide-triangle-alert',
      iconBg: 'bg-n-amber-3',
      iconColor: 'text-n-amber-11',
      progressColor: 'bg-n-amber-9',
    },
    info: {
      icon: 'i-lucide-info',
      iconBg: 'bg-n-blue-3',
      iconColor: 'text-n-blue-11',
      progressColor: 'bg-n-blue-9',
    },
  };
  return configs[variant.value] || configs.info;
});

const animateProgress = timestamp => {
  if (!startTime) startTime = timestamp;
  const elapsed = timestamp - startTime;
  const remaining = Math.max(0, 100 - (elapsed / props.duration) * 100);
  progressWidth.value = remaining;

  if (remaining > 0) {
    animationFrame = requestAnimationFrame(animateProgress);
  }
};

onMounted(() => {
  animationFrame = requestAnimationFrame(animateProgress);
});

onBeforeUnmount(() => {
  if (animationFrame) cancelAnimationFrame(animationFrame);
});
</script>

<template>
  <div
    class="group relative flex items-center gap-3 rounded-2xl border border-n-border-glass bg-n-glass-strong backdrop-blur-glass-card backdrop-saturate-glass px-4 py-3 shadow-glass-deep"
    role="alert"
    @click="emit('dismiss')"
  >
    <!-- Icon -->
    <div
      class="flex size-8 shrink-0 items-center justify-center rounded-full"
      :class="[variantConfig.iconBg]"
    >
      <span
        class="size-[18px]"
        :class="[variantConfig.icon, variantConfig.iconColor]"
      />
    </div>

    <!-- Content -->
    <div class="flex min-w-0 flex-1 items-center gap-3">
      <p
        class="min-w-0 flex-1 text-sm font-medium leading-snug text-n-text-display"
      >
        {{ message }}
      </p>
      <router-link
        v-if="action?.type === 'link'"
        :to="action.to"
        class="shrink-0 text-sm font-semibold text-n-blue-11 transition-colors hover:text-n-blue-12"
      >
        {{ action.message }}
      </router-link>
    </div>

    <!-- Progress bar -->
    <div
      class="absolute inset-x-4 bottom-0 h-[2px] overflow-hidden rounded-full bg-n-slate-4/50"
    >
      <div
        class="h-full rounded-full transition-none"
        :class="[variantConfig.progressColor]"
        :style="{ width: `${progressWidth}%` }"
      />
    </div>
  </div>
</template>
