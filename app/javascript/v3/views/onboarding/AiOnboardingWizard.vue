<script setup>
import { ref, computed, nextTick, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const store = useStore();
const { t } = useI18n();

const globalConfig = computed(() => store.getters['globalConfig/get']);
const chatContainer = ref(null);
const userInput = ref('');
const isTyping = ref(false);

const CHANNELS = [
  {
    id: 'whatsapp',
    label: 'ONBOARDING_WIZARD.CHANNEL_WHATSAPP',
    icon: 'i-lucide-message-circle',
    color: 'bg-green-500',
  },
  {
    id: 'telegram',
    label: 'ONBOARDING_WIZARD.CHANNEL_TELEGRAM',
    icon: 'i-lucide-send',
    color: 'bg-blue-500',
  },
  {
    id: 'vk',
    label: 'ONBOARDING_WIZARD.CHANNEL_VK',
    icon: 'i-lucide-messages-square',
    color: 'bg-sky-600',
  },
  {
    id: 'email',
    label: 'ONBOARDING_WIZARD.CHANNEL_EMAIL',
    icon: 'i-lucide-mail',
    color: 'bg-amber-500',
  },
  {
    id: 'website',
    label: 'ONBOARDING_WIZARD.CHANNEL_WEBSITE',
    icon: 'i-lucide-globe',
    color: 'bg-purple-500',
  },
];

const STEPS = {
  WELCOME: 'welcome',
  CHANNELS: 'channels',
  CONNECTING: 'connecting',
  ANALYZING: 'analyzing',
  BUSINESS_TYPE: 'business_type',
  AGENTS_CREATED: 'agents_created',
  TOP_QUESTIONS: 'top_questions',
  COMPLETE: 'complete',
};

const currentStep = ref(STEPS.WELCOME);
const selectedChannels = ref([]);
const connectedChannels = ref([]);
const businessType = ref('');
const messages = ref([]);

const analysisResults = ref({
  contacts: 847,
  faqPairs: 34,
  requestTypes: 5,
  toneDetected: true,
});

const suggestedAgents = ref([]);
const topQuestions = ref([]);

async function scrollToBottom() {
  await nextTick();
  if (chatContainer.value) {
    chatContainer.value.scrollTop = chatContainer.value.scrollHeight;
  }
}

function addMessage(type, content, options = {}) {
  messages.value.push({
    id: Date.now() + Math.random(),
    type,
    content,
    ...options,
  });
  scrollToBottom();
}

function addBotMessage(content, options = {}) {
  isTyping.value = true;
  return new Promise(resolve => {
    setTimeout(
      () => {
        isTyping.value = false;
        addMessage('bot', content, options);
        resolve();
      },
      800 + Math.random() * 600
    );
  });
}

function addUserMessage(content) {
  addMessage('user', content);
}

async function startWizard() {
  await addBotMessage(t('ONBOARDING_WIZARD.WELCOME'));
  await addBotMessage(t('ONBOARDING_WIZARD.CHOOSE_CHANNELS'), {
    component: 'channels',
  });
  currentStep.value = STEPS.CHANNELS;
}

function toggleChannel(channelId) {
  const idx = selectedChannels.value.indexOf(channelId);
  if (idx >= 0) {
    selectedChannels.value.splice(idx, 1);
  } else {
    selectedChannels.value.push(channelId);
  }
}

async function connectChannels() {
  if (selectedChannels.value.length === 0) return;

  const channelNames = selectedChannels.value
    .map(id => CHANNELS.find(c => c.id === id))
    .filter(Boolean)
    .map(c => t(c.label))
    .join(', ');

  addUserMessage(channelNames);
  currentStep.value = STEPS.CONNECTING;

  const addChannelMessages = selectedChannels.value.reduce(
    (chain, channelId) => {
      const ch = CHANNELS.find(c => c.id === channelId);
      return chain.then(() =>
        addBotMessage(
          t('ONBOARDING_WIZARD.AUTH_CHANNEL', { channel: t(ch.label) }),
          { component: 'auth_button', channelId }
        )
      );
    },
    Promise.resolve()
  );
  await addChannelMessages;
}

async function authorizeChannel(channelId) {
  connectedChannels.value.push(channelId);

  if (connectedChannels.value.length === selectedChannels.value.length) {
    currentStep.value = STEPS.ANALYZING;
    await addBotMessage(t('ONBOARDING_WIZARD.ANALYZING'), {
      component: 'analysis',
    });

    await new Promise(resolve => {
      setTimeout(resolve, 2000);
    });

    currentStep.value = STEPS.BUSINESS_TYPE;

    businessType.value = 'restaurant';
    await addBotMessage(
      t('ONBOARDING_WIZARD.BUSINESS_QUESTION', { type: businessType.value }),
      { component: 'business_confirm' }
    );
  }
}

async function confirmBusiness(confirmed) {
  if (confirmed) {
    addUserMessage(t('ONBOARDING_WIZARD.YES'));
  } else {
    addUserMessage(t('ONBOARDING_WIZARD.NO'));
  }

  currentStep.value = STEPS.AGENTS_CREATED;

  suggestedAgents.value = [
    { name: 'Hostess', emoji: '🍽️', description: 'Reservations & booking' },
    {
      name: 'Menu Consultant',
      emoji: '📋',
      description: 'Menu & recommendations',
    },
    { name: 'Manager', emoji: '🎯', description: 'Escalation & complaints' },
  ];

  await addBotMessage(
    t('ONBOARDING_WIZARD.AGENTS_CREATED', {
      count: suggestedAgents.value.length,
    }),
    { component: 'agents_list' }
  );

  topQuestions.value = [
    'What are your delivery hours?',
    'Do you have gluten-free options?',
    'What is the minimum order?',
    'Do you have a loyalty program?',
    'Can I modify my order?',
  ];

  currentStep.value = STEPS.TOP_QUESTIONS;
  await addBotMessage(
    t('ONBOARDING_WIZARD.TOP_QUESTIONS', {
      count: topQuestions.value.length,
    }),
    { component: 'top_questions' }
  );

  await addBotMessage(t('ONBOARDING_WIZARD.ADD_ANYTHING'));
}

async function handleUserInput() {
  const text = userInput.value.trim();
  if (!text) return;

  addUserMessage(text);
  userInput.value = '';

  if (currentStep.value === STEPS.TOP_QUESTIONS) {
    await addBotMessage(t('ONBOARDING_WIZARD.ALL_SET'), {
      component: 'finish',
    });
    currentStep.value = STEPS.COMPLETE;
  }
}

async function skipSetup() {
  window.location = '/app';
}

async function finishSetup() {
  window.location = '/app';
}

function skipChannel() {
  // Mark all remaining as skipped and proceed
  connectedChannels.value = [...selectedChannels.value];
  addBotMessage(t('ONBOARDING_WIZARD.ANALYZING'), {
    component: 'analysis',
  }).then(async () => {
    await new Promise(resolve => {
      setTimeout(resolve, 2000);
    });
    currentStep.value = STEPS.BUSINESS_TYPE;
    businessType.value = 'restaurant';
    await addBotMessage(
      t('ONBOARDING_WIZARD.BUSINESS_QUESTION', { type: businessType.value }),
      { component: 'business_confirm' }
    );
  });
}

onMounted(() => {
  startWizard();
});
</script>

<template>
  <main
    class="flex items-center justify-center w-full min-h-screen bg-gradient-to-br from-n-brand/5 via-n-background to-n-brand/10 dark:from-n-background dark:via-n-solid-1 dark:to-n-background p-4"
  >
    <div
      class="w-full max-w-2xl mx-auto flex flex-col bg-white dark:bg-n-solid-2 rounded-2xl shadow-lg ring-1 ring-n-container/50 dark:ring-n-container overflow-hidden h-[680px]"
    >
      <!-- Header -->
      <div
        class="flex items-center justify-between px-6 py-4 border-b border-n-container bg-n-background/50 dark:bg-n-solid-3/50"
      >
        <div class="flex items-center gap-3">
          <div
            class="flex items-center justify-center w-10 h-10 rounded-xl bg-n-brand/10"
          >
            <Icon icon="i-lucide-bot" class="size-5 text-n-brand" />
          </div>
          <div>
            <h2 class="text-base font-semibold text-n-slate-12">
              {{ $t('ONBOARDING_WIZARD.TITLE') }}
            </h2>
            <p class="text-xs text-n-slate-10">
              {{ globalConfig.installationName }}
            </p>
          </div>
        </div>
        <button
          class="text-sm text-n-slate-10 hover:text-n-slate-12 transition-colors"
          @click="skipSetup"
        >
          {{ $t('ONBOARDING_WIZARD.SKIP') }}
        </button>
      </div>

      <!-- Chat Messages -->
      <div ref="chatContainer" class="flex-1 overflow-y-auto p-6 space-y-4">
        <template v-for="msg in messages" :key="msg.id">
          <!-- Bot Message -->
          <div v-if="msg.type === 'bot'" class="flex items-start gap-3">
            <div
              class="flex-shrink-0 flex items-center justify-center w-8 h-8 rounded-full bg-n-brand/10"
            >
              <Icon icon="i-lucide-bot" class="size-4 text-n-brand" />
            </div>
            <div class="flex-1 max-w-md">
              <div
                class="bg-n-background dark:bg-n-solid-3 rounded-2xl rounded-tl-sm px-4 py-3 text-sm text-n-slate-12"
              >
                {{ msg.content }}
              </div>

              <!-- Channel Selection -->
              <div
                v-if="msg.component === 'channels'"
                class="mt-3 flex flex-wrap gap-2"
              >
                <button
                  v-for="channel in CHANNELS"
                  :key="channel.id"
                  class="flex items-center gap-2 px-3 py-2 rounded-xl text-sm font-medium transition-all ring-1"
                  :class="
                    selectedChannels.includes(channel.id)
                      ? 'bg-n-brand/10 text-n-brand ring-n-brand/30'
                      : 'bg-white dark:bg-n-solid-3 text-n-slate-11 ring-n-container hover:ring-n-brand/30'
                  "
                  @click="toggleChannel(channel.id)"
                >
                  <Icon :icon="channel.icon" class="size-4" />
                  {{ $t(channel.label) }}
                </button>
                <div v-if="selectedChannels.length > 0" class="w-full mt-2">
                  <NextButton
                    sm
                    :label="$t('ONBOARDING_WIZARD.CONTINUE')"
                    @click="connectChannels"
                  />
                </div>
              </div>

              <!-- Auth Button -->
              <div
                v-if="msg.component === 'auth_button'"
                class="mt-3 flex gap-2"
              >
                <NextButton
                  v-if="!connectedChannels.includes(msg.channelId)"
                  sm
                  :label="
                    $t('ONBOARDING_WIZARD.AUTH_BUTTON', {
                      channel: $t(
                        CHANNELS.find(c => c.id === msg.channelId)?.label || ''
                      ),
                    })
                  "
                  @click="authorizeChannel(msg.channelId)"
                />
                <button
                  v-if="!connectedChannels.includes(msg.channelId)"
                  class="text-sm text-n-slate-10 hover:text-n-slate-12 transition-colors px-3"
                  @click="skipChannel"
                >
                  {{ $t('ONBOARDING_WIZARD.CONNECT_LATER') }}
                </button>
                <div
                  v-else
                  class="flex items-center gap-1 text-sm text-green-600"
                >
                  <Icon icon="i-lucide-check-circle" class="size-4" />
                  {{ $t('ONBOARDING_WIZARD.CONNECTED') }}
                </div>
              </div>

              <!-- Analysis Progress -->
              <div
                v-if="msg.component === 'analysis'"
                class="mt-3 bg-n-background dark:bg-n-solid-3 rounded-xl p-4 ring-1 ring-n-container"
              >
                <div
                  class="flex items-center gap-2 mb-3 text-sm font-semibold text-n-slate-12"
                >
                  <Icon icon="i-lucide-search" class="size-4 text-n-brand" />
                  {{ $t('ONBOARDING_WIZARD.ANALYSIS_COMPLETE') }}
                </div>
                <div class="space-y-2">
                  <div class="flex items-center gap-2 text-sm text-n-slate-11">
                    <Icon icon="i-lucide-check" class="size-4 text-green-500" />
                    {{
                      $t('ONBOARDING_WIZARD.CONTACTS_EXTRACTED', {
                        count: analysisResults.contacts,
                      })
                    }}
                  </div>
                  <div class="flex items-center gap-2 text-sm text-n-slate-11">
                    <Icon icon="i-lucide-check" class="size-4 text-green-500" />
                    {{
                      $t('ONBOARDING_WIZARD.FAQ_RECOGNIZED', {
                        count: analysisResults.faqPairs,
                      })
                    }}
                  </div>
                  <div class="flex items-center gap-2 text-sm text-n-slate-11">
                    <Icon icon="i-lucide-check" class="size-4 text-green-500" />
                    {{
                      $t('ONBOARDING_WIZARD.REQUEST_TYPES', {
                        count: analysisResults.requestTypes,
                      })
                    }}
                  </div>
                  <div class="flex items-center gap-2 text-sm text-n-slate-11">
                    <Icon icon="i-lucide-check" class="size-4 text-green-500" />
                    {{ $t('ONBOARDING_WIZARD.TONE_DETECTED') }}
                  </div>
                </div>
              </div>

              <!-- Business Confirm -->
              <div
                v-if="msg.component === 'business_confirm'"
                class="mt-3 flex gap-2"
              >
                <NextButton
                  sm
                  :label="$t('ONBOARDING_WIZARD.YES')"
                  @click="confirmBusiness(true)"
                />
                <button
                  class="px-4 py-2 text-sm font-medium text-n-slate-11 bg-n-background dark:bg-n-solid-3 rounded-lg ring-1 ring-n-container hover:bg-n-alpha-2 transition-colors"
                  @click="confirmBusiness(false)"
                >
                  {{ $t('ONBOARDING_WIZARD.NO') }}
                </button>
              </div>

              <!-- Agents List -->
              <div
                v-if="msg.component === 'agents_list'"
                class="mt-3 space-y-2"
              >
                <div
                  v-for="agent in suggestedAgents"
                  :key="agent.name"
                  class="flex items-center gap-3 p-3 bg-n-background dark:bg-n-solid-3 rounded-xl ring-1 ring-n-container"
                >
                  <span class="text-xl">{{ agent.emoji }}</span>
                  <div>
                    <div class="text-sm font-medium text-n-slate-12">
                      {{ agent.name }}
                    </div>
                    <div class="text-xs text-n-slate-10">
                      {{ agent.description }}
                    </div>
                  </div>
                </div>
              </div>

              <!-- Top Questions -->
              <div
                v-if="msg.component === 'top_questions'"
                class="mt-3 bg-n-background dark:bg-n-solid-3 rounded-xl p-4 ring-1 ring-n-container"
              >
                <ol class="list-decimal list-inside space-y-1.5">
                  <li
                    v-for="(q, idx) in topQuestions"
                    :key="idx"
                    class="text-sm text-n-slate-11"
                  >
                    {{ q }}
                  </li>
                </ol>
              </div>

              <!-- Finish -->
              <div v-if="msg.component === 'finish'" class="mt-3 flex gap-2">
                <NextButton
                  sm
                  :label="$t('ONBOARDING_WIZARD.GO_TO_DASHBOARD')"
                  @click="finishSetup"
                />
              </div>
            </div>
          </div>

          <!-- User Message -->
          <div v-if="msg.type === 'user'" class="flex justify-end">
            <div
              class="max-w-md bg-n-brand text-white rounded-2xl rounded-tr-sm px-4 py-3 text-sm"
            >
              {{ msg.content }}
            </div>
          </div>
        </template>

        <!-- Typing Indicator -->
        <div v-if="isTyping" class="flex items-start gap-3">
          <div
            class="flex-shrink-0 flex items-center justify-center w-8 h-8 rounded-full bg-n-brand/10"
          >
            <Icon icon="i-lucide-bot" class="size-4 text-n-brand" />
          </div>
          <div
            class="bg-n-background dark:bg-n-solid-3 rounded-2xl rounded-tl-sm px-4 py-3"
          >
            <div class="flex gap-1">
              <span class="w-2 h-2 bg-n-slate-8 rounded-full animate-bounce" />
              <span
                class="w-2 h-2 bg-n-slate-8 rounded-full animate-bounce [animation-delay:0.15s]"
              />
              <span
                class="w-2 h-2 bg-n-slate-8 rounded-full animate-bounce [animation-delay:0.3s]"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Input Area -->
      <div
        v-if="currentStep !== STEPS.COMPLETE"
        class="px-6 py-4 border-t border-n-container bg-n-background/50 dark:bg-n-solid-3/50"
      >
        <form class="flex gap-3" @submit.prevent="handleUserInput">
          <input
            v-model="userInput"
            type="text"
            :placeholder="$t('ONBOARDING_WIZARD.TYPE_MESSAGE')"
            class="flex-1 px-4 py-2.5 bg-white dark:bg-n-solid-2 rounded-xl text-sm text-n-slate-12 placeholder-n-slate-8 ring-1 ring-n-container focus:ring-n-brand focus:outline-none transition-shadow"
          />
          <button
            type="submit"
            class="flex items-center justify-center w-10 h-10 bg-n-brand text-white rounded-xl hover:bg-n-brand/90 transition-colors"
          >
            <Icon icon="i-lucide-send" class="size-4" />
          </button>
        </form>
      </div>
    </div>
  </main>
</template>
