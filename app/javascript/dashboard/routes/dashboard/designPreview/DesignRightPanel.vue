<script setup>
import { ref } from 'vue';

defineProps({
  pane: { type: String, default: null },
  conv: { type: Object, required: true },
});

const emit = defineEmits(['close']);

const open = ref({
  actions: true,
  info: true,
  history: false,
  macros: false,
  notes: false,
  appts: false,
});
const toggle = key => {
  open.value[key] = !open.value[key];
};

const suggestions = [
  'Кратко пересказать этот диалог',
  'Предложить ответ',
  'Оценить этот диалог',
  'Найти похожие случаи',
];

const actionChips = [
  { icon: 'i-lucide-user', label: 'Назначить' },
  { icon: 'i-lucide-hash', label: 'Метки' },
  { icon: 'i-lucide-clock', label: 'Отложить' },
  { icon: 'i-lucide-check', label: 'Решено' },
];

const previousDialogs = [
  { date: '12 апр', title: 'Резерв стола на 4 персоны', status: 'Решено' },
  { date: '28 мар', title: 'Возврат заказа №4521', status: 'Решено' },
  { date: '14 фев', title: 'Программа лояльности', status: 'Решено' },
];

const macros = [
  { emoji: '⚡', label: 'Отправить меню' },
  { emoji: '📍', label: 'Адреса филиалов' },
  { emoji: '🎁', label: 'Скидка постоянного' },
];

const timeline = [
  ['11:18', 'Captain передал диалог оператору'],
  ['11:20', 'Оператор начал отвечать'],
  ['11:22', 'Отправлен уточняющий вопрос'],
];
</script>

<template>
  <aside
    class="w-[300px] min-w-[300px] rounded-[24px] flex flex-col min-h-0 overflow-hidden bg-white/70 backdrop-blur-[22px] backdrop-saturate-150 border border-white/90 shadow-[0_1px_0_rgba(255,255,255,0.9)_inset,0_20px_50px_-22px_rgba(28,56,96,0.16),0_4px_14px_-6px_rgba(28,56,96,0.08)]"
  >
    <header
      class="px-4 py-3.5 flex items-center justify-between border-b border-slate-900/5"
    >
      <div class="text-sm font-bold text-[#1A1B1F]">
        <template v-if="pane === 'copilot'">Copilot</template>
        <template v-else-if="pane === 'contact'">Контакт</template>
        <template v-else-if="pane === 'metrics'">Метрики</template>
      </div>
      <button
        class="size-7 rounded-[10px] bg-slate-900/5 cursor-pointer text-slate-600 inline-flex items-center justify-center"
        @click="emit('close')"
      >
        <span class="i-lucide-x size-3.5" />
      </button>
    </header>

    <div class="flex-1 overflow-y-auto p-4">
      <!-- Copilot -->
      <template v-if="pane === 'copilot'">
        <div
          class="size-9 rounded-[10px] bg-white/70 border border-slate-900/5 inline-flex items-center justify-center text-slate-600 text-lg font-bold mb-3.5"
        >
          "
        </div>
        <div
          class="font-interDisplay text-lg font-bold text-[#1A1B1F] mb-1.5 tracking-tight"
        >
          Начать работу с Copilot
        </div>
        <p class="text-[12.5px] text-slate-600 leading-normal m-0">
          Нужна краткая выжимка, проверка прошлых диалогов или черновик ответа?
          Copilot поможет ускорить работу.
        </p>
        <div
          class="text-[11px] text-slate-500 uppercase tracking-wide font-semibold mt-5 mb-2"
        >
          Попробуйте эти запросы
        </div>
        <div class="flex flex-col gap-1.5">
          <button
            v-for="(s, i) in suggestions"
            :key="i"
            class="flex items-center justify-between w-full bg-white/55 border border-white/70 px-3 py-2.5 rounded-xl cursor-pointer text-[12.5px] text-[#1A1B1F] font-medium text-left"
          >
            <span>{{ s }}</span>
            <span class="i-lucide-chevron-right size-3.5 flex-shrink-0" />
          </button>
        </div>
      </template>

      <!-- Contact -->
      <template v-else-if="pane === 'contact'">
        <div class="flex items-center gap-2.5 mb-3.5">
          <div
            class="size-11 rounded-[14px] text-white inline-flex items-center justify-center font-bold text-[17px] flex-shrink-0"
            :style="{ background: conv.color }"
          >
            {{ conv.initials }}
          </div>
          <div class="flex-1 min-w-0">
            <div
              class="font-interDisplay text-[15px] font-bold text-[#1A1B1F] tracking-tight"
            >
              {{ conv.name }}
            </div>
            <div class="text-[11px] text-slate-500 mt-0.5">
              VIP · 14 заказов
            </div>
          </div>
          <button
            class="size-[26px] rounded-lg bg-slate-900/5 cursor-pointer text-slate-600 inline-flex items-center justify-center"
          >
            <span class="i-lucide-pen-line size-3" />
          </button>
        </div>

        <div class="flex flex-col gap-1 mb-3">
          <div class="flex items-center gap-2.5 px-1 py-2">
            <span class="i-lucide-mail size-3 text-slate-500" />
            <div class="flex-1 min-w-0">
              <div
                class="text-[10.5px] text-slate-500 uppercase tracking-wide font-semibold"
              >
                Email
              </div>
              <div
                class="text-[12.5px] text-[#1A1B1F] mt-px font-medium truncate"
              >
                leonid@example.com
              </div>
            </div>
          </div>
          <div class="flex items-center gap-2.5 px-1 py-2">
            <span class="i-lucide-at-sign size-3 text-slate-500" />
            <div class="flex-1 min-w-0">
              <div
                class="text-[10.5px] text-slate-500 uppercase tracking-wide font-semibold"
              >
                Telegram
              </div>
              <div
                class="text-[12.5px] text-[#1A1B1F] mt-px font-medium truncate"
              >
                @rakitin_l
              </div>
            </div>
          </div>
          <div class="flex items-center gap-2.5 px-1 py-2">
            <span class="i-lucide-lock size-3 text-slate-500" />
            <div class="flex-1 min-w-0">
              <div
                class="text-[10.5px] text-slate-500 uppercase tracking-wide font-semibold"
              >
                ID
              </div>
              <div
                class="text-[12.5px] text-[#1A1B1F] mt-px font-medium truncate"
              >
                CsI1139753
              </div>
            </div>
          </div>
        </div>

        <div
          class="flex gap-1.5 p-1.5 bg-slate-900/[0.04] rounded-[14px] mb-3.5"
        >
          <button
            class="flex-1 h-[30px] rounded-[10px] bg-white cursor-pointer text-slate-600 inline-flex items-center justify-center"
          >
            <span class="i-lucide-message-circle size-3.5" />
          </button>
          <button
            class="flex-1 h-[30px] rounded-[10px] bg-white cursor-pointer text-slate-600 inline-flex items-center justify-center"
          >
            <span class="i-lucide-pen-line size-3.5" />
          </button>
          <button
            class="flex-1 h-[30px] rounded-[10px] bg-white cursor-pointer text-slate-600 inline-flex items-center justify-center"
          >
            <span class="i-lucide-mail size-3.5" />
          </button>
          <button
            class="flex-1 h-[30px] rounded-[10px] bg-white cursor-pointer text-[#E5484D] inline-flex items-center justify-center"
          >
            <span class="i-lucide-x size-3.5" />
          </button>
        </div>

        <div class="flex flex-col gap-2">
          <!-- Actions chip widget -->
          <div
            class="bg-white/55 border border-white/70 rounded-[14px] overflow-hidden"
          >
            <button
              class="flex items-center gap-2 w-full px-3 py-2.5 cursor-pointer text-xs font-semibold text-[#1A1B1F] text-left"
              @click="toggle('actions')"
            >
              <span
                class="flex-1 truncate min-w-0 overflow-hidden text-ellipsis whitespace-nowrap"
                >Действия в беседе</span
              >
              <span
                class="text-[10px] font-bold px-[7px] py-px rounded-full bg-[#1A1B1F] text-white"
                >4</span
              >
              <span
                class="i-lucide-chevron-down size-3 text-slate-500 transition-transform"
                :class="{ 'rotate-180': open.actions }"
              />
            </button>
            <div v-if="open.actions" class="px-3 pb-3">
              <div class="grid grid-cols-2 gap-1.5">
                <button
                  v-for="(c, i) in actionChips"
                  :key="i"
                  class="inline-flex items-center gap-1.5 px-2.5 py-2 border border-slate-900/[0.08] bg-white rounded-[10px] cursor-pointer text-xs font-medium text-[#1A1B1F]"
                >
                  <span
                    class="inline-flex text-slate-600 size-3"
                    :class="c.icon"
                  />
                  <span>{{ c.label }}</span>
                </button>
              </div>
            </div>
          </div>

          <!-- Info widget — kv table -->
          <div
            class="bg-white/55 border border-white/70 rounded-[14px] overflow-hidden"
          >
            <button
              class="flex items-center gap-2 w-full px-3 py-2.5 cursor-pointer text-xs font-semibold text-[#1A1B1F] text-left"
              @click="toggle('info')"
            >
              <span class="flex-1 truncate">Информация о беседе</span>
              <span
                class="i-lucide-chevron-down size-3 text-slate-500 transition-transform"
                :class="{ 'rotate-180': open.info }"
              />
            </button>
            <div v-if="open.info" class="px-3 pb-3">
              <div class="flex flex-col gap-0.5">
                <div class="flex justify-between items-center py-1 text-xs">
                  <span class="text-slate-500">Канал</span>
                  <span
                    class="text-[#1A1B1F] font-medium inline-flex items-center gap-1.5"
                  >
                    <span
                      class="text-[9px] font-bold text-white px-1.5 py-px rounded bg-[#0077FF]"
                      >VK</span
                    >
                    ВКонтакте
                  </span>
                </div>
                <div class="flex justify-between items-center py-1 text-xs">
                  <span class="text-slate-500">Создано</span>
                  <span class="text-[#1A1B1F] font-medium">3 ч назад</span>
                </div>
                <div class="flex justify-between items-center py-1 text-xs">
                  <span class="text-slate-500">SLA</span>
                  <span class="text-[#30A46C] font-semibold">В норме</span>
                </div>
                <div class="flex justify-between items-center py-1 text-xs">
                  <span class="text-slate-500">Команда</span>
                  <span class="text-[#1A1B1F] font-medium"
                    >Поддержка · Москва</span
                  >
                </div>
              </div>
            </div>
          </div>

          <!-- History -->
          <div
            class="bg-white/55 border border-white/70 rounded-[14px] overflow-hidden"
          >
            <button
              class="flex items-center gap-2 w-full px-3 py-2.5 cursor-pointer text-xs font-semibold text-[#1A1B1F] text-left"
              @click="toggle('history')"
            >
              <span class="flex-1 truncate">Предыдущие диалоги</span>
              <span
                class="text-[10px] font-bold px-[7px] py-px rounded-full bg-[#1A1B1F] text-white"
                >3</span
              >
              <span
                class="i-lucide-chevron-down size-3 text-slate-500 transition-transform"
                :class="{ 'rotate-180': open.history }"
              />
            </button>
            <div v-if="open.history" class="px-3 pb-3">
              <div class="flex flex-col gap-1">
                <div
                  v-for="(r, i) in previousDialogs"
                  :key="i"
                  class="flex items-center gap-2.5 px-2.5 py-2 rounded-[10px] bg-white/55 border border-slate-900/[0.05] cursor-pointer text-slate-500"
                >
                  <div
                    class="text-[10.5px] text-slate-500 font-semibold min-w-[38px]"
                  >
                    {{ r.date }}
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="text-xs font-semibold text-[#1A1B1F] truncate">
                      {{ r.title }}
                    </div>
                    <div
                      class="text-[10.5px] text-slate-500 inline-flex items-center gap-1.5 mt-0.5"
                    >
                      <span class="size-1.5 rounded-full bg-[#30A46C]" />
                      {{ r.status }}
                    </div>
                  </div>
                  <span class="i-lucide-chevron-right size-3" />
                </div>
              </div>
            </div>
          </div>

          <!-- Macros -->
          <div
            class="bg-white/55 border border-white/70 rounded-[14px] overflow-hidden"
          >
            <button
              class="flex items-center gap-2 w-full px-3 py-2.5 cursor-pointer text-xs font-semibold text-[#1A1B1F] text-left"
              @click="toggle('macros')"
            >
              <span class="flex-1 truncate">Макросы</span>
              <span
                class="text-[10px] font-bold px-[7px] py-px rounded-full bg-[#1A1B1F] text-white"
                >6</span
              >
              <span
                class="i-lucide-chevron-down size-3 text-slate-500 transition-transform"
                :class="{ 'rotate-180': open.macros }"
              />
            </button>
            <div v-if="open.macros" class="px-3 pb-3">
              <div class="flex flex-col gap-1">
                <button
                  v-for="(m, i) in macros"
                  :key="i"
                  class="flex items-center gap-2.5 px-2.5 py-2 rounded-[10px] border border-slate-900/[0.06] bg-white cursor-pointer"
                >
                  <span class="text-base leading-none w-5 text-center">{{
                    m.emoji
                  }}</span>
                  <span
                    class="flex-1 text-xs font-medium text-[#1A1B1F] text-left"
                    >{{ m.label }}</span
                  >
                  <span class="i-lucide-arrow-right size-3" />
                </button>
              </div>
            </div>
          </div>

          <!-- Notes -->
          <div
            class="bg-white/55 border border-white/70 rounded-[14px] overflow-hidden"
          >
            <button
              class="flex items-center gap-2 w-full px-3 py-2.5 cursor-pointer text-xs font-semibold text-[#1A1B1F] text-left"
              @click="toggle('notes')"
            >
              <span class="flex-1 truncate">Заметки</span>
              <span
                class="text-[10px] font-bold px-[7px] py-px rounded-full bg-[#1A1B1F] text-white"
                >2</span
              >
              <span
                class="i-lucide-chevron-down size-3 text-slate-500 transition-transform"
                :class="{ 'rotate-180': open.notes }"
              />
            </button>
            <div v-if="open.notes" class="px-3 pb-3">
              <div class="flex flex-col gap-1.5">
                <div
                  class="bg-[rgba(251,229,107,0.18)] border border-[rgba(245,215,0,0.3)] p-2.5 rounded-[10px]"
                >
                  <div class="flex justify-between items-center mb-1.5">
                    <span class="text-[10.5px] font-bold text-[#1A1B1F]"
                      >Анна К.</span
                    >
                    <span class="text-[10px] text-slate-500">3 дня назад</span>
                  </div>
                  <div class="text-xs text-[#1A1B1F] leading-snug">
                    VIP-клиент, аллергия на орехи. Учитывать при заказе.
                  </div>
                </div>
                <div
                  class="bg-[rgba(91,141,239,0.08)] border border-[rgba(245,215,0,0.3)] p-2.5 rounded-[10px]"
                >
                  <div class="flex justify-between items-center mb-1.5">
                    <span class="text-[10.5px] font-bold text-[#1A1B1F]"
                      >Captain</span
                    >
                    <span class="text-[10px] text-slate-500">авто</span>
                  </div>
                  <div class="text-xs text-[#1A1B1F] leading-snug">
                    Часто заказывает после 19:00 в Пятницу.
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Appointments -->
          <div
            class="bg-white/55 border border-white/70 rounded-[14px] overflow-hidden"
          >
            <button
              class="flex items-center gap-2 w-full px-3 py-2.5 cursor-pointer text-xs font-semibold text-[#1A1B1F] text-left"
              @click="toggle('appts')"
            >
              <span class="flex-1 truncate">YClients · записи</span>
              <span
                class="text-[10px] font-bold px-[7px] py-px rounded-full bg-[#1A1B1F] text-white"
                >1</span
              >
              <span
                class="i-lucide-chevron-down size-3 text-slate-500 transition-transform"
                :class="{ 'rotate-180': open.appts }"
              />
            </button>
            <div v-if="open.appts" class="px-3 pb-3">
              <div
                class="flex items-center gap-2.5 p-2.5 rounded-[10px] bg-gradient-to-br from-[rgba(91,141,239,0.12)] to-[rgba(91,141,239,0.04)] border border-[rgba(91,141,239,0.25)]"
              >
                <div
                  class="w-[38px] py-1 rounded-lg bg-white text-center flex-shrink-0 border border-slate-900/[0.06]"
                >
                  <div
                    class="text-base font-extrabold text-[#1A1B1F] leading-none font-interDisplay"
                  >
                    04
                  </div>
                  <div
                    class="text-[9px] font-semibold text-slate-500 tracking-wide mt-0.5"
                  >
                    МАЯ
                  </div>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="text-[12.5px] font-semibold text-[#1A1B1F]">
                    Стол на 4 · 19:30
                  </div>
                  <div class="text-[11px] text-slate-500 mt-0.5">
                    Кирова, 12 · подтверждено
                  </div>
                </div>
                <span class="size-2 rounded-full bg-[#30A46C] flex-shrink-0" />
              </div>
            </div>
          </div>
        </div>
      </template>

      <!-- Metrics -->
      <template v-else-if="pane === 'metrics'">
        <div class="grid grid-cols-3 gap-1.5 mb-1">
          <div
            class="p-3 rounded-[14px] text-white bg-gradient-to-br from-[#3B6EE0] to-[#5B8DEF]"
          >
            <div
              class="text-[22px] font-extrabold leading-none font-interDisplay"
            >
              76%
            </div>
            <div class="text-[10.5px] font-semibold mt-1.5 opacity-85">
              Авто-ответ
            </div>
          </div>
          <div class="p-3 rounded-[14px] text-white bg-[#1A1B1F]">
            <div
              class="text-[22px] font-extrabold leading-none font-interDisplay"
            >
              3
            </div>
            <div class="text-[10.5px] font-semibold mt-1.5 opacity-85">
              Эскалаций
            </div>
          </div>
          <div class="p-3 rounded-[14px] text-[#3F3000] bg-[#FBE56B]">
            <div
              class="text-[22px] font-extrabold leading-none font-interDisplay"
            >
              4.6
            </div>
            <div class="text-[10.5px] font-semibold mt-1.5 opacity-85">
              CSAT
            </div>
          </div>
        </div>
        <div
          class="text-[11px] text-slate-500 uppercase tracking-wide font-semibold mt-5 mb-2"
        >
          Активность
        </div>
        <div class="flex flex-col gap-2">
          <div
            v-for="([t, msg], i) in timeline"
            :key="i"
            class="flex gap-2.5 px-2.5 py-2 bg-white/55 rounded-[10px]"
          >
            <div class="text-[11px] text-slate-500 font-semibold min-w-[36px]">
              {{ t }}
            </div>
            <div class="text-xs text-[#1A1B1F]">{{ msg }}</div>
          </div>
        </div>
      </template>
    </div>

    <div v-if="pane === 'copilot'" class="p-3 border-t border-slate-900/5">
      <div
        class="inline-flex items-center gap-1.5 text-[11px] text-slate-500 mb-2"
      >
        <span class="size-1.5 rounded-full bg-[#30A46C]" />
        Новый ассистент
      </div>
      <div class="flex gap-1.5">
        <input
          placeholder="Отправить сообщение..."
          class="flex-1 border border-slate-900/[0.08] bg-white/55 px-3 py-2 rounded-full outline-none text-[12.5px] min-w-0"
        />
        <button
          class="size-8 rounded-full cursor-pointer bg-[#1A1B1F] text-white inline-flex items-center justify-center"
        >
          <span class="i-lucide-arrow-right size-3.5" />
        </button>
      </div>
    </div>
  </aside>
</template>
