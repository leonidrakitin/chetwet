<script setup>
import { computed, ref } from 'vue';

const initialFAQs = [
  {
    id: 1,
    q: 'Почему мой Messenger в EstBot отключён?',
    a: 'Возможно, вы на бесплатном плане или достигнут лимит инбоксов. Проверьте подписку в разделе Настройки → Биллинг.',
    when: 'over 1 year ago',
    expanded: true,
    channel: 'Messenger',
  },
  {
    id: 2,
    q: 'Как интегрировать WhatsApp с EstBot?',
    a: 'Подключите WhatsApp Business через мастер создания инбокса. Нужен бизнес-аккаунт и подтверждённый номер.',
    when: 'over 1 year ago',
    expanded: false,
    channel: 'WhatsApp',
  },
  {
    id: 3,
    q: 'Что делать с парковкой на ул. Пушкино?',
    a: 'Парковка платная. Уточните у клиента, нужна ли альтернатива рядом — на Кирова бесплатно.',
    when: 'just now',
    expanded: false,
    badge: 'NEW',
    channel: 'FAQ',
  },
  {
    id: 4,
    q: 'Можно ли изменить часы работы салона?',
    a: 'Да, в разделе Настройки → Расписание. Капитан учтёт это при ответах клиентам.',
    when: '3 days ago',
    expanded: false,
    channel: 'FAQ',
  },
];

const tab = ref('faq');
const faqs = ref([...initialFAQs]);
const search = ref('');

const visible = computed(() => {
  const q = search.value.toLowerCase();
  return faqs.value.filter(
    f => f.q.toLowerCase().includes(q) || f.a.toLowerCase().includes(q)
  );
});

const tabs = computed(() => [
  { key: 'faq', label: 'FAQ', count: faqs.value.length },
  { key: 'docs', label: 'Документы', count: 8 },
  { key: 'scen', label: 'Сценарии', count: 3 },
]);

const toggle = id => {
  const target = faqs.value.find(f => f.id === id);
  if (target) target.expanded = !target.expanded;
};

const stats = [
  {
    tone: 'dark',
    big: '142',
    label: 'FAQ записей',
    sub: '+ 4 за неделю',
  },
  {
    tone: 'blue',
    big: '76%',
    label: 'Авто-ответ',
    sub: 'Покрытие диалогов',
  },
  {
    tone: 'yellow',
    big: '4.6',
    label: 'CSAT',
    sub: 'средний за месяц',
  },
];

const statClasses = tone => {
  if (tone === 'dark') return 'bg-[#1A1B1F] text-white';
  if (tone === 'blue')
    return 'bg-gradient-to-br from-[#3B6EE0] to-[#5B8DEF] text-white';
  return 'bg-[#FBE56B] text-[#3F3000]';
};
</script>

<template>
  <main
    class="flex-1 min-w-0 flex flex-col gap-3.5 h-full pl-0 pr-[18px] pt-3.5 pb-[18px]"
  >
    <header class="flex items-center gap-2.5">
      <div class="flex items-center gap-3">
        <button
          class="size-9 rounded-[14px] border-0 cursor-pointer inline-flex items-center justify-center text-[#1A1B1F] bg-white/55 backdrop-blur-[16px] backdrop-saturate-150 border border-white/75"
        >
          <span class="i-lucide-chevron-left size-4" />
        </button>
        <h1
          class="font-interDisplay m-0 text-[28px] font-bold text-[#1A1B1F] tracking-tight"
        >
          База знаний
        </h1>
        <span
          class="text-[13px] text-slate-500 inline-flex items-center gap-1 font-medium"
        >
          Новый ассистент
          <span class="i-lucide-chevron-down size-3" />
        </span>
      </div>
      <div class="flex-1" />
      <div
        class="inline-flex items-center gap-2 px-3.5 py-2 rounded-full text-slate-600 w-60 bg-white/55 backdrop-blur-[16px] backdrop-saturate-150 border border-white/75"
      >
        <span class="i-lucide-search size-3.5" />
        <input
          v-model="search"
          placeholder="Поиск по FAQ..."
          class="flex-1 border-0 outline-none bg-transparent text-[13px] text-[#1A1B1F] min-w-0"
        />
      </div>
      <button
        class="bg-[#1A1B1F] text-white border-0 px-3.5 py-2 rounded-full text-[12.5px] font-semibold cursor-pointer inline-flex items-center gap-1.5 shadow-[0_8px_18px_-8px_rgba(0,0,0,0.4)]"
      >
        <span class="i-lucide-plus size-3.5" />
        Создать FAQ
      </button>
    </header>

    <div class="flex-1 min-h-0 flex">
      <section
        class="flex-1 rounded-[28px] p-4 flex flex-col min-h-0 overflow-hidden bg-white/70 backdrop-blur-[22px] backdrop-saturate-150 border border-white/90 shadow-[0_1px_0_rgba(255,255,255,0.9)_inset,0_20px_50px_-22px_rgba(28,56,96,0.16),0_4px_14px_-6px_rgba(28,56,96,0.08)]"
      >
        <div
          class="flex items-center gap-1 p-1 bg-slate-900/5 rounded-full mb-3.5 self-start"
        >
          <button
            v-for="t in tabs"
            :key="t.key"
            class="border-0 px-4 py-1.5 rounded-full cursor-pointer text-[13px] font-semibold inline-flex items-center gap-2 transition-all duration-150"
            :class="
              tab === t.key
                ? 'bg-[#1A1B1F] text-white shadow-[0_8px_18px_-6px_rgba(0,0,0,0.35)]'
                : 'bg-transparent text-slate-600'
            "
            @click="tab = t.key"
          >
            {{ t.label }}
            <span
              class="text-[11px] font-bold px-[7px] py-px rounded-full"
              :class="
                tab === t.key
                  ? 'bg-white/15 text-white'
                  : 'bg-slate-900/[0.06] text-slate-600'
              "
            >
              {{ t.count }}
            </span>
          </button>

          <div class="flex-1" />

          <div
            class="inline-flex bg-slate-900/5 rounded-[10px] p-[3px] ml-auto"
          >
            <button
              class="size-7 border-0 rounded-lg cursor-pointer text-slate-600 inline-flex items-center justify-center bg-white shadow-[0_1px_2px_rgba(0,0,0,0.06)]"
            >
              <span class="i-lucide-hash size-3" />
            </button>
            <button
              class="size-7 border-0 rounded-lg bg-transparent cursor-pointer text-slate-600 inline-flex items-center justify-center"
            >
              <span class="i-lucide-message-circle size-3" />
            </button>
          </div>
        </div>

        <template v-if="tab === 'faq'">
          <!-- Suggestion banner -->
          <div
            class="flex items-center gap-4 p-4 rounded-[22px] bg-gradient-to-br from-[#1A1B1F] to-[#2a2c33] text-white mb-3.5 shadow-[0_20px_40px_-20px_rgba(0,0,0,0.4)]"
          >
            <div
              class="size-14 rounded-[18px] bg-[#FBE56B] text-[#3F3000] inline-flex items-center justify-center flex-shrink-0"
            >
              <span class="i-woot-captain size-6" />
            </div>
            <div class="flex-1">
              <div class="text-base font-bold mb-1">
                Капитан нашёл 3 новые подсказки
              </div>
              <div class="text-[13px] text-white/75 leading-normal">
                Из последних 28 диалогов он выделил повторяющиеся вопросы.
                Одобрите или отклоните каждую — это улучшит автоответы.
              </div>
            </div>
            <button
              class="bg-[#FBE56B] text-[#3F3000] border-0 px-4 py-2.5 rounded-full text-[12.5px] font-semibold cursor-pointer inline-flex items-center gap-1.5 flex-shrink-0"
            >
              Открыть подсказки
              <span class="i-lucide-arrow-right size-3.5" />
            </button>
          </div>

          <!-- Stat row -->
          <div class="grid grid-cols-3 gap-3 mb-3.5">
            <div
              v-for="s in stats"
              :key="s.label"
              class="p-4 rounded-[20px] shadow-[0_16px_30px_-16px_rgba(15,23,42,0.25)]"
              :class="statClasses(s.tone)"
            >
              <div
                class="font-interDisplay text-3xl font-extrabold leading-none"
              >
                {{ s.big }}
              </div>
              <div class="text-[13px] font-semibold mt-2">{{ s.label }}</div>
              <div class="text-[11.5px] mt-0.5 opacity-80">{{ s.sub }}</div>
            </div>
          </div>

          <div class="flex flex-col gap-2.5 overflow-y-auto pr-0.5 flex-1">
            <div
              v-for="f in visible"
              :key="f.id"
              class="rounded-[18px] py-1 px-1 bg-white/55 backdrop-blur-[16px] backdrop-saturate-150 border border-white/75"
            >
              <button
                class="flex items-center gap-2.5 w-full px-3.5 py-3 border-0 bg-transparent cursor-pointer text-[13.5px] text-[#1A1B1F] text-left"
                @click="toggle(f.id)"
              >
                <span class="inline-flex text-slate-500 size-3.5">
                  <span
                    :class="
                      f.expanded
                        ? 'i-lucide-chevron-down'
                        : 'i-lucide-chevron-right'
                    "
                    class="size-3.5"
                  />
                </span>
                <span class="font-semibold">{{ f.q }}</span>
                <span
                  class="text-[10.5px] font-semibold px-2 py-[3px] rounded-full bg-slate-900/[0.06] text-slate-600"
                >
                  {{ f.channel }}
                </span>
                <span
                  v-if="f.badge"
                  class="text-[10px] font-bold tracking-wide text-[#3F3000] bg-[#FBE56B] px-[7px] py-0.5 rounded-full"
                >
                  {{ f.badge }}
                </span>
                <span class="flex-1" />
                <span
                  class="inline-flex items-center gap-1 text-[11px] text-slate-500"
                >
                  <span class="i-lucide-clock size-2.5" />
                  {{ f.when }}
                </span>
              </button>
              <div
                v-if="f.expanded"
                class="flex gap-3 px-3.5 pl-8 pb-3.5 text-slate-600 text-[13px] leading-relaxed"
              >
                <div
                  class="size-[22px] rounded-lg bg-[#1A1B1F] text-white inline-flex items-center justify-center text-[11px] font-bold flex-shrink-0"
                >
                  a
                </div>
                <div class="flex-1">
                  <div>{{ f.a }}</div>
                  <div class="flex items-center gap-3 mt-2.5">
                    <button
                      class="bg-transparent border-0 cursor-pointer text-xs text-slate-600 inline-flex items-center gap-1 p-0 font-medium"
                    >
                      <span class="i-lucide-pen-line size-3" />
                      Редактировать
                    </button>
                    <button
                      class="bg-transparent border-0 cursor-pointer text-xs text-slate-600 inline-flex items-center gap-1 p-0 font-medium"
                    >
                      <span class="i-lucide-sparkles size-3" />
                      Сгенерировать варианты
                    </button>
                    <span class="flex-1" />
                    <button
                      class="bg-[#1A1B1F] text-white border-0 px-3 py-1.5 rounded-full text-[11.5px] font-semibold cursor-pointer"
                    >
                      Применить
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <div
              v-if="visible.length === 0"
              class="text-center py-10 px-5 text-slate-600"
            >
              <div
                class="font-interDisplay text-[22px] font-bold text-[#1A1B1F] mb-1.5 tracking-tight"
              >
                Ничего не найдено
              </div>
              <div class="text-[13px] leading-relaxed max-w-md mx-auto">
                Попробуйте другой запрос или создайте новый FAQ.
              </div>
            </div>
          </div>
        </template>

        <template v-else-if="tab === 'docs'">
          <div class="text-center py-10 px-5 text-slate-600">
            <div
              class="font-interDisplay text-[22px] font-bold text-[#1A1B1F] mb-1.5 tracking-tight"
            >
              Документы
            </div>
            <div class="text-[13px] leading-relaxed max-w-md mx-auto">
              Загрузите PDF, DOCX или Markdown — Капитан будет искать ответы по
              содержимому.
            </div>
          </div>
        </template>

        <template v-else-if="tab === 'scen'">
          <div class="text-center py-10 px-5 text-slate-600">
            <div
              class="font-interDisplay text-[22px] font-bold text-[#1A1B1F] mb-1.5 tracking-tight"
            >
              Сценарии
            </div>
            <div class="text-[13px] leading-relaxed max-w-md mx-auto">
              Запись, отмена, жалобы — опишите многошаговые диалоги для
              ассистента.
            </div>
          </div>
        </template>
      </section>
    </div>
  </main>
</template>
