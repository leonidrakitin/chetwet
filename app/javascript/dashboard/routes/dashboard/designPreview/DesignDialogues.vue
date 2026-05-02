<script setup>
import { computed, nextTick, ref, watch } from 'vue';

import DesignBubble from './DesignBubble.vue';
import DesignRightPanel from './DesignRightPanel.vue';

const conversations = [
  {
    id: 1,
    name: 'Леонид Ракитин',
    handle: 'CsI1139753',
    last: 'Разговор закрывается, посколь...',
    time: '3h',
    color: 'linear-gradient(135deg,#5B8DEF,#3B6EE0)',
    initials: 'Л',
    unread: 0,
    channel: 'VK',
  },
  {
    id: 2,
    name: 'Анна Соколова',
    handle: 'sokolova_a',
    last: 'Спасибо! А когда будет в наличии?',
    time: '5m',
    color: 'linear-gradient(135deg,#F5B544,#E0942C)',
    initials: 'А',
    unread: 2,
    channel: 'WA',
  },
  {
    id: 3,
    name: 'Михаил Петров',
    handle: 'mpetrov',
    last: 'Хочу записаться на консультацию',
    time: '12m',
    color: 'linear-gradient(135deg,#34D1B0,#1FA68B)',
    initials: 'М',
    unread: 1,
    channel: 'TG',
  },
  {
    id: 4,
    name: 'Ирина Власова',
    handle: 'vlasova',
    last: 'Капитан передал диалог оператору',
    time: '1h',
    color: 'linear-gradient(135deg,#B98CFF,#7E5BE0)',
    initials: 'И',
    unread: 0,
    channel: 'VK',
  },
];

const channelMap = {
  VK: { bg: '#0077FF', label: 'VK' },
  WA: { bg: '#25D366', label: 'WA' },
  TG: { bg: '#229ED9', label: 'TG' },
  IG: { bg: '#E1306C', label: 'IG' },
};

const initialMessages = [
  { type: 'system', text: 'Диалог открыт · Администратор салона' },
  { type: 'system', text: 'CsI1139753 назначен ответственным' },
  {
    type: 'agent',
    text: 'Леонид, сейчас передам ваш вопрос о парковке нашему специалисту, который сможет дать вам точную информацию.',
  },
  {
    type: 'captain',
    body: 'Клиент спрашивает о бесплатной парковке. В FAQ указано: «На Кирова парковка есть, на Пушкино платная». Требуется уточнение у оператора.',
    label: 'Selected option',
    prompt: 'Хотите записаться на консультацию?',
    hint: 'Отредактируйте и отправьте ответ ниже',
  },
  { type: 'event', text: 'Captain передал диалог оператору', time: '11:18' },
  {
    type: 'agent',
    text: 'Добрый день! Подскажите, пожалуйста, о каком именно филиале идёт речь?',
  },
];

const active = ref(1);
const messages = ref([...initialMessages]);
const reply = ref('');
const tab = ref('reply');
const pane = ref('copilot');

const conv = computed(
  () => conversations.find(c => c.id === active.value) || conversations[0]
);

const chatBody = ref(null);
watch(
  messages,
  async () => {
    await nextTick();
    if (chatBody.value) chatBody.value.scrollTop = chatBody.value.scrollHeight;
  },
  { deep: true }
);

const selectConversation = id => {
  active.value = id;
  if (id === 1) {
    messages.value = [...initialMessages];
  } else {
    const target = conversations.find(c => c.id === id);
    messages.value = [
      { type: 'system', text: `Диалог с ${target?.name ?? ''}` },
    ];
  }
};

const send = () => {
  const text = reply.value.trim();
  if (!text) return;
  messages.value.push({
    type: tab.value === 'note' ? 'note' : 'agent',
    text,
  });
  reply.value = '';
};

const onComposerKeydown = event => {
  if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) {
    event.preventDefault();
    send();
  }
};

const togglePane = name => {
  pane.value = pane.value === name ? null : name;
};
</script>

<template>
  <main
    class="flex-1 min-w-0 flex flex-col gap-3.5 h-full pl-0 pr-[18px] pt-3.5 pb-[18px]"
  >
    <!-- Top bar -->
    <header class="flex items-center gap-2.5 px-1 py-1.5 min-h-[52px]">
      <div class="flex-1" />
      <button
        class="relative size-10 rounded-full bg-white/70 border border-white/90 cursor-pointer text-[rgb(60,78,104)] inline-flex items-center justify-center shadow-[0_6px_14px_-8px_rgba(28,56,96,0.15)]"
        title="Уведомления"
      >
        <span class="i-lucide-mail size-3.5" />
        <span
          class="absolute top-2 right-[9px] size-2 rounded-full bg-[#E5484D] border-2 border-white"
        />
      </button>
      <button
        class="inline-flex items-center gap-2.5 pl-1.5 pr-3 py-1.5 rounded-full bg-white/70 border border-white/90 cursor-pointer text-[#1A1B1F] shadow-[0_6px_14px_-8px_rgba(28,56,96,0.15)]"
      >
        <span
          class="size-8 rounded-full bg-[#1A1B1F] text-white inline-flex items-center justify-center font-bold text-[13px]"
        >
          C
        </span>
        <div class="flex flex-col text-left leading-tight">
          <div class="text-[12.5px] font-semibold">CsI1139753</div>
          <div class="text-[10.5px] text-slate-500">csl@dsd.com</div>
        </div>
        <span class="i-lucide-chevron-down size-3" />
      </button>
    </header>

    <!-- Body -->
    <div class="flex-1 min-h-0 flex gap-3.5 min-w-0 overflow-x-auto">
      <!-- List island -->
      <section
        class="w-[300px] flex-shrink-0 rounded-[24px] p-3.5 flex flex-col min-h-0 h-full bg-white/70 backdrop-blur-[22px] backdrop-saturate-150 border border-white/90 shadow-[0_1px_0_rgba(255,255,255,0.9)_inset,0_20px_50px_-22px_rgba(28,56,96,0.16),0_4px_14px_-6px_rgba(28,56,96,0.08)]"
      >
        <div class="px-1.5 pt-5 pb-3.5 flex flex-col gap-1">
          <div class="flex items-center justify-between gap-2.5">
            <h2
              class="font-interDisplay m-0 text-2xl font-bold text-[#1A1B1F] tracking-tight leading-tight whitespace-nowrap"
            >
              В работе
            </h2>
            <span
              class="bg-[#1A1B1F] text-white px-2.5 py-1 rounded-full text-xs font-semibold"
            >
              {{ conversations.length }}
            </span>
          </div>
          <div class="text-[11.5px] text-slate-500 mt-0.5">
            {{ conversations.length }} активных диалогов
          </div>
          <div
            class="flex gap-1.5 mt-3 bg-[rgba(28,56,96,0.06)] p-1 rounded-xl w-fit"
          >
            <button
              class="size-[30px] rounded-[9px] cursor-pointer bg-transparent text-[rgb(60,78,104)] inline-flex items-center justify-center hover:bg-white/50 transition-colors"
              title="Поиск"
            >
              <span class="i-lucide-search size-3" />
            </button>
            <button
              class="size-[30px] rounded-[9px] cursor-pointer bg-transparent text-[rgb(60,78,104)] inline-flex items-center justify-center hover:bg-white/50 transition-colors"
              title="Фильтр"
            >
              <span class="i-lucide-filter size-3" />
            </button>
            <button
              class="size-[30px] rounded-[9px] cursor-pointer bg-transparent text-[rgb(60,78,104)] inline-flex items-center justify-center hover:bg-white/50 transition-colors"
              title="Сортировка"
            >
              <span class="i-lucide-arrow-up-down size-3" />
            </button>
          </div>
        </div>

        <div class="flex-1 overflow-y-auto flex flex-col gap-2 pr-0.5">
          <button
            v-for="c in conversations"
            :key="c.id"
            class="flex gap-2.5 p-2.5 rounded-2xl cursor-pointer text-left transition-all duration-150 border"
            :class="
              c.id === active
                ? 'bg-[#1A1B1F] text-white border-[#1A1B1F] shadow-[0_14px_30px_-10px_rgba(0,0,0,0.45)]'
                : 'bg-white/55 text-[#1A1B1F] border-white/70 shadow-[0_1px_0_rgba(255,255,255,0.7)_inset]'
            "
            @click="selectConversation(c.id)"
          >
            <div class="relative flex-shrink-0">
              <div
                class="size-[38px] rounded-[14px] text-white inline-flex items-center justify-center font-bold text-sm flex-shrink-0"
                :style="{ background: c.color }"
              >
                {{ c.initials }}
              </div>
              <span
                class="absolute -right-[3px] -bottom-[3px] size-[18px] rounded-full text-white text-[8px] font-extrabold tracking-wide inline-flex items-center justify-center"
                :style="{
                  background: channelMap[c.channel].bg,
                  border:
                    c.id === active
                      ? '2px solid #1A1B1F'
                      : '2px solid rgba(255,255,255,0.95)',
                }"
              >
                {{ channelMap[c.channel].label }}
              </span>
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex justify-between items-baseline gap-1.5 min-w-0">
                <span
                  class="text-[13.5px] font-semibold flex-1 min-w-0 truncate"
                  :class="c.id === active ? 'text-white' : 'text-[#1A1B1F]'"
                  >{{ c.name }}</span
                >
                <span
                  class="text-[11px] flex-shrink-0"
                  :class="c.id === active ? 'text-white/70' : 'text-slate-500'"
                  >{{ c.time }}</span
                >
              </div>
              <div
                class="text-xs mt-0.5 truncate"
                :class="c.id === active ? 'text-white/75' : 'text-slate-500'"
              >
                {{ c.last }}
              </div>
              <div v-if="c.unread > 0" class="flex items-center gap-1.5 mt-1.5">
                <span
                  class="bg-[#FBE56B] text-[#3F3000] text-[10px] font-bold px-1.5 py-0.5 rounded-full"
                >
                  {{ c.unread }} новых
                </span>
              </div>
            </div>
          </button>
        </div>
      </section>

      <!-- Chat island -->
      <section
        class="flex-1 min-w-[420px] rounded-[24px] p-3.5 flex flex-col min-h-0 bg-white/70 backdrop-blur-[22px] backdrop-saturate-150 border border-white/90 shadow-[0_1px_0_rgba(255,255,255,0.9)_inset,0_20px_50px_-22px_rgba(28,56,96,0.16),0_4px_14px_-6px_rgba(28,56,96,0.08)]"
      >
        <header
          class="flex items-center gap-2.5 pb-3 border-b border-slate-900/[0.06]"
        >
          <div
            class="size-10 rounded-[14px] text-white inline-flex items-center justify-center font-bold text-[15px]"
            :style="{ background: conv.color }"
          >
            {{ conv.initials }}
          </div>
          <div class="min-w-0">
            <div class="text-[15px] font-bold text-[#1A1B1F]">
              {{ conv.name }}
            </div>
            <div
              class="text-[11.5px] text-slate-500 inline-flex items-center gap-1.5"
            >
              <span class="size-[7px] rounded-full bg-[#30A46C]" />
              Онлайн · {{ conv.channel }}
            </div>
          </div>
          <div class="flex-1" />
          <button
            class="bg-white/60 border border-white/80 px-3 py-[7px] rounded-xl cursor-pointer text-[12.5px] font-medium text-[#1A1B1F]"
          >
            Hand back to Captain
          </button>
          <div class="inline-flex rounded-xl overflow-hidden bg-[#1A1B1F]">
            <button
              class="bg-transparent text-white border-0 px-3.5 py-[7px] cursor-pointer text-[12.5px] font-semibold"
            >
              Завершить
            </button>
            <button
              class="bg-transparent text-white border-0 border-l border-white/15 px-2 cursor-pointer inline-flex items-center justify-center"
            >
              <span class="i-lucide-chevron-down size-3" />
            </button>
          </div>
          <button
            class="size-8 rounded-[10px] bg-transparent cursor-pointer text-slate-600 inline-flex items-center justify-center"
          >
            <span class="i-lucide-more-horizontal size-4" />
          </button>
        </header>

        <div
          ref="chatBody"
          class="flex-1 overflow-y-auto py-3.5 px-1 flex flex-col gap-2.5"
        >
          <DesignBubble v-for="(m, i) in messages" :key="i" :m="m" />
        </div>

        <!-- Composer -->
        <div
          class="mt-2.5 bg-white/45 border border-white/70 rounded-[18px] backdrop-blur-[20px]"
        >
          <div class="flex items-center p-1.5 gap-1.5">
            <div
              class="inline-flex bg-slate-900/5 rounded-full p-[3px] gap-0.5"
            >
              <button
                class="border-0 px-3.5 py-1.5 rounded-full cursor-pointer text-[12.5px] font-semibold transition-colors"
                :class="
                  tab === 'reply'
                    ? 'bg-[#1A1B1F] text-white'
                    : 'bg-transparent text-slate-600'
                "
                @click="tab = 'reply'"
              >
                Ответить
              </button>
              <button
                class="border-0 px-3.5 py-1.5 rounded-full cursor-pointer text-[12.5px] font-semibold transition-colors"
                :class="
                  tab === 'note'
                    ? 'bg-[#FBE56B] text-[#3F3000]'
                    : 'bg-transparent text-slate-600'
                "
                @click="tab = 'note'"
              >
                Личная заметка
              </button>
            </div>
            <div class="flex-1" />
            <button
              class="size-8 rounded-[10px] bg-transparent cursor-pointer text-slate-600 inline-flex items-center justify-center"
            >
              <span class="i-lucide-sparkles size-3.5" />
            </button>
            <button
              class="size-8 rounded-[10px] bg-transparent cursor-pointer text-slate-600 inline-flex items-center justify-center"
            >
              <span class="i-lucide-expand size-3.5" />
            </button>
          </div>

          <textarea
            v-model="reply"
            class="w-full border-0 outline-none resize-none px-3.5 py-2.5 min-h-14 text-[13.5px] leading-normal text-[#1A1B1F] backdrop-blur-[8px] border-y border-white/60 transition-colors"
            :class="
              tab === 'note' ? 'bg-[rgba(251,229,107,0.18)]' : 'bg-white/55'
            "
            placeholder="Shift + Enter — новая строка. Начните с « / », чтобы выбрать шаблон."
            @keydown="onComposerKeydown"
          />

          <div class="flex items-center p-1.5 gap-1">
            <button
              class="size-8 rounded-[10px] bg-transparent cursor-pointer text-slate-600 inline-flex items-center justify-center"
            >
              <span class="i-lucide-smile size-4" />
            </button>
            <button
              class="size-8 rounded-[10px] bg-transparent cursor-pointer text-slate-600 inline-flex items-center justify-center"
            >
              <span class="i-lucide-paperclip size-4" />
            </button>
            <button
              class="size-8 rounded-[10px] bg-transparent cursor-pointer text-slate-600 inline-flex items-center justify-center"
            >
              <span class="i-lucide-mic size-4" />
            </button>
            <button
              class="size-8 rounded-[10px] bg-transparent cursor-pointer text-slate-600 inline-flex items-center justify-center"
            >
              <span class="i-lucide-slash size-4" />
            </button>
            <div class="flex-1" />
            <button
              class="bg-[#1A1B1F] text-white border-0 px-4 py-2 rounded-full text-[12.5px] font-semibold cursor-pointer inline-flex items-center gap-2 shadow-[0_8px_18px_-8px_rgba(0,0,0,0.4)] transition-opacity"
              :class="reply.trim() ? 'opacity-100' : 'opacity-55'"
              @click="send"
            >
              Отправить
              <span
                class="text-[10px] opacity-60 bg-white/10 px-1.5 py-0.5 rounded"
                >⌘↵</span
              >
            </button>
          </div>
        </div>
      </section>

      <!-- Right pane (collapsible) -->
      <DesignRightPanel
        v-if="pane"
        :pane="pane"
        :conv="conv"
        @close="pane = null"
      />

      <!-- Right rail -->
      <div class="w-11 min-w-[44px] flex-shrink-0 flex flex-col gap-2 pt-1.5">
        <button
          class="size-10 rounded-[14px] cursor-pointer inline-flex items-center justify-center backdrop-blur-[16px] border border-white/70 transition-all shadow-[0_1px_0_rgba(255,255,255,0.7)_inset]"
          :class="
            pane === 'contact'
              ? 'bg-[#1A1B1F] text-white'
              : 'bg-white/55 text-slate-600'
          "
          title="Контакт"
          @click="togglePane('contact')"
        >
          <span class="i-lucide-user size-4" />
        </button>
        <button
          class="size-10 rounded-[14px] cursor-pointer inline-flex items-center justify-center backdrop-blur-[16px] border border-white/70 transition-all shadow-[0_1px_0_rgba(255,255,255,0.7)_inset]"
          :class="
            pane === 'copilot'
              ? 'bg-[#1A1B1F] text-white'
              : 'bg-white/55 text-slate-600'
          "
          title="Copilot"
          @click="togglePane('copilot')"
        >
          <span class="i-lucide-sparkles size-4" />
        </button>
        <button
          class="size-10 rounded-[14px] cursor-pointer inline-flex items-center justify-center backdrop-blur-[16px] border border-white/70 transition-all shadow-[0_1px_0_rgba(255,255,255,0.7)_inset]"
          :class="
            pane === 'metrics'
              ? 'bg-[#1A1B1F] text-white'
              : 'bg-white/55 text-slate-600'
          "
          title="Метрики"
          @click="togglePane('metrics')"
        >
          <span class="i-lucide-chart-spline size-4" />
        </button>
      </div>
    </div>
  </main>
</template>
