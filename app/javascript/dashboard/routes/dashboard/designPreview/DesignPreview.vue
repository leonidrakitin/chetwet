<script setup>
import { ref } from 'vue';

import DesignSidebar from './DesignSidebar.vue';
import DesignDialogues from './DesignDialogues.vue';
import DesignCaptain from './DesignCaptain.vue';

const route = ref('dialogues');
const expanded = ref(false);
</script>

<template>
  <div
    class="flex h-screen w-screen overflow-hidden font-inter text-[#1A1B1F]"
    :style="{
      background:
        'radial-gradient(1200px 700px at 100% 0%, #DCE5F0 0%, transparent 60%),' +
        'radial-gradient(900px 600px at 0% 100%, #D6E3F2 0%, transparent 60%),' +
        'radial-gradient(700px 500px at 50% 40%, #E8EEF7 0%, transparent 65%),' +
        '#E2E9F2',
    }"
  >
    <DesignSidebar v-model:route="route" v-model:expanded="expanded" />
    <DesignDialogues v-if="route === 'dialogues'" />
    <DesignCaptain v-else-if="route === 'captain'" />
    <main v-else class="flex-1 min-w-0 p-[14px_18px_18px_0]">
      <div
        class="bg-white/70 backdrop-blur-[22px] backdrop-saturate-150 border border-white/90 rounded-[28px] p-10 h-full flex flex-col items-center justify-center text-center text-slate-600 shadow-[0_1px_0_rgba(255,255,255,0.9)_inset,0_20px_50px_-22px_rgba(28,56,96,0.16),0_4px_14px_-6px_rgba(28,56,96,0.08)]"
      >
        <h2
          class="font-interDisplay text-[26px] font-bold m-0 text-[#1A1B1F] tracking-tight"
        >
          Раздел в работе
        </h2>
        <p class="mt-2">
          Этот раздел пока не реализован в прототипе. Откройте Диалоги или
          Капитан.
        </p>
      </div>
    </main>
  </div>
</template>
