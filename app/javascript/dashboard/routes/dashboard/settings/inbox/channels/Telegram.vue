<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import PageHeader from '../../SettingsSubPageHeader.vue';

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const botToken = ref('');
const isSubmitting = ref(false);
const hasBot = ref(null);

const rules = { botToken: { required } };
const v$ = useVuelidate(rules, { botToken });

const allSteps = computed(() => [
  t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS.STEP_1'),
  t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS.STEP_2'),
  t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS.STEP_3'),
  t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS.STEP_4'),
  t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS.STEP_5'),
]);

const hasBotSteps = computed(() => [
  t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS_HAS_BOT.STEP_1'),
  t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS_HAS_BOT.STEP_2'),
  t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS_HAS_BOT.STEP_3'),
]);

const steps = computed(() =>
  hasBot.value ? hasBotSteps.value : allSteps.value
);
const stepsTitle = computed(() =>
  hasBot.value
    ? t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS_HAS_BOT.TITLE')
    : t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS.TITLE')
);

const createChannel = async () => {
  await v$.value.$validate();
  if (v$.value.$invalid) return;

  isSubmitting.value = true;
  try {
    const telegramChannel = await store.dispatch('inboxes/createChannel', {
      channel: {
        type: 'telegram',
        bot_token: botToken.value,
      },
    });
    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: telegramChannel.id },
    });
  } catch (error) {
    useAlert(
      error.message || t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.API.ERROR_MESSAGE')
    );
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.DESC')"
    />

    <!-- Step 0: bot status selection -->
    <div v-if="hasBot === null" class="grid grid-cols-2 gap-4 mt-4">
      <button
        class="text-left flex flex-col p-5 rounded-2xl outline outline-1 outline-n-weak hover:outline-n-brand transition-all cursor-pointer"
        @click="hasBot = true"
      >
        <span class="font-semibold text-sm text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.HAS_BOT.YES') }}
        </span>
        <span class="text-xs text-n-slate-11 mt-1">
          {{ $t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.HAS_BOT.YES_DESC') }}
        </span>
      </button>
      <button
        class="text-left flex flex-col p-5 rounded-2xl outline outline-1 outline-n-weak hover:outline-n-brand transition-all cursor-pointer"
        @click="hasBot = false"
      >
        <span class="font-semibold text-sm text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.HAS_BOT.NO') }}
        </span>
        <span class="text-xs text-n-slate-11 mt-1">
          {{ $t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.HAS_BOT.NO_DESC') }}
        </span>
      </button>
    </div>

    <!-- Setup form (shown after bot status is selected) -->
    <template v-else>
      <div
        class="rounded-2xl outline outline-1 outline-n-weak p-5 mb-6 bg-n-alpha-1 mt-4"
      >
        <p class="text-sm font-semibold text-n-slate-12 mb-4">
          {{ stepsTitle }}
        </p>
        <ol class="space-y-3">
          <li
            v-for="(step, index) in steps"
            :key="index"
            class="flex items-start gap-3"
          >
            <span
              class="flex-shrink-0 w-5 h-5 rounded-full bg-n-brand text-white text-xs font-semibold flex items-center justify-center mt-0.5"
            >
              {{ index + 1 }}
            </span>
            <span
              v-dompurify-html="step"
              class="text-sm text-n-slate-11 leading-5"
            />
          </li>
        </ol>
        <p
          v-if="!hasBot"
          v-dompurify-html="$t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.DIRECT_LINK')"
          class="text-sm text-n-slate-11 mt-4 pl-8"
        />
      </div>

      <form
        class="flex flex-wrap flex-col mx-0"
        @submit.prevent="createChannel"
      >
        <div class="flex-shrink-0 flex-grow-0">
          <label :class="{ error: v$.botToken.$error }">
            {{ $t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.BOT_TOKEN.LABEL') }}
            <input
              v-model="botToken"
              type="text"
              :placeholder="
                $t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.BOT_TOKEN.PLACEHOLDER')
              "
              @blur="v$.botToken.$touch"
            />
          </label>
          <p class="help-text">
            {{ $t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.BOT_TOKEN.SUBTITLE') }}
          </p>
        </div>

        <div class="w-full mt-4">
          <Button
            :is-loading="isSubmitting"
            type="submit"
            solid
            blue
            icon="i-woot-telegram"
            :label="$t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.SUBMIT_BUTTON')"
          />
        </div>
      </form>
    </template>
  </div>
</template>
