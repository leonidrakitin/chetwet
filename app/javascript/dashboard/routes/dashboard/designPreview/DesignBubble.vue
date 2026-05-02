<script setup>
defineProps({
  m: { type: Object, required: true },
});
</script>

<template>
  <div v-if="m.type === 'system'" class="flex justify-center">
    <span
      class="text-[11px] text-slate-600 bg-white/55 px-3 py-1 rounded-full border border-white/70"
    >
      {{ m.text }}
    </span>
  </div>

  <div v-else-if="m.type === 'event'" class="flex justify-end">
    <div
      class="inline-flex items-start gap-2 bg-white/55 border border-white/70 px-3 py-2 rounded-[14px] text-[12.5px] text-slate-600"
    >
      <span class="i-lucide-bot size-3.5 mt-0.5 flex-shrink-0" />
      <div>
        <div>{{ m.text }}</div>
        <div v-if="m.time" class="text-[10.5px] text-slate-500 mt-0.5">
          {{ m.time }}
        </div>
      </div>
    </div>
  </div>

  <div v-else-if="m.type === 'agent'" class="flex justify-end">
    <div
      class="max-w-[78%] px-3.5 py-2.5 rounded-[18px_18px_4px_18px] text-[13.5px] leading-normal text-[#1A1B1F] bg-gradient-to-br from-white/85 to-white/55"
    >
      {{ m.text }}
    </div>
  </div>

  <div v-else-if="m.type === 'note'" class="flex justify-end">
    <div
      class="max-w-[78%] bg-[rgba(251,229,107,0.55)] text-[#3F3000] px-3.5 py-2.5 rounded-[18px_18px_4px_18px] text-[13.5px] border border-[rgba(245,215,0,0.4)] backdrop-blur-[10px]"
    >
      {{ m.text }}
    </div>
  </div>

  <div v-else-if="m.type === 'captain'" class="flex justify-end">
    <div
      class="max-w-[78%] p-3.5 rounded-[18px_18px_4px_18px] bg-gradient-to-br from-[#1A1B1F] to-[#2a2c33] text-white text-[13px] leading-normal shadow-[0_14px_30px_-10px_rgba(0,0,0,0.35)]"
    >
      <div
        class="flex items-center gap-2 text-[11px] text-white/60 mb-2 uppercase tracking-wide font-semibold"
      >
        <div
          class="size-6 rounded-lg bg-[#FBE56B] text-[#3F3000] inline-flex items-center justify-center"
        >
          <span class="i-lucide-bot size-3.5" />
        </div>
        <span>Captain · подсказка</span>
      </div>
      <div class="text-white/90 mb-2.5">{{ m.body }}</div>
      <div class="text-[10.5px] text-white/55 uppercase tracking-wide mb-1.5">
        {{ m.label }}
      </div>
      <div
        class="bg-white/10 border border-white/15 px-3 py-2 rounded-[10px] text-white text-[13px]"
      >
        {{ m.prompt }}
      </div>
      <div class="text-[11px] text-white/50 mt-2">{{ m.hint }}</div>
    </div>
  </div>
</template>
