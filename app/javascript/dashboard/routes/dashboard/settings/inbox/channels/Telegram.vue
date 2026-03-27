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

const rules = { botToken: { required } };
const v$ = useVuelidate(rules, { botToken });

const steps = computed(() => [
  t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS.STEP_1'),
  t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS.STEP_2'),
  t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS.STEP_3'),
  t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS.STEP_4'),
  t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS.STEP_5'),
]);

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

    <div
      class="rounded-2xl outline outline-1 outline-n-weak p-5 mb-6 bg-n-alpha-1"
    >
      <p class="text-sm font-semibold text-n-slate-12 mb-4">
        {{ $t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.STEPS.TITLE') }}
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
        v-dompurify-html="$t('INBOX_MGMT.ADD.TELEGRAM_CHANNEL.DIRECT_LINK')"
        class="text-sm text-n-slate-11 mt-4 pl-8"
      />
    </div>

    <form class="flex flex-wrap flex-col mx-0" @submit.prevent="createChannel">
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
  </div>
</template>
