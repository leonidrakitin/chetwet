<script setup>
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useTrack } from 'dashboard/composables';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { ACCOUNT_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import Avatar from 'next/avatar/Avatar.vue';
import Spinner from 'shared/components/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { DropdownContainer, DropdownBody } from 'next/dropdown-menu/base';

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const { accountScopedRoute } = useAccount();

const dropdownRef = ref(null);

const notificationMetadata = useMapGetter('notifications/getMeta');
const records = useMapGetter('notifications/getNotifications');
const uiFlags = useMapGetter('notifications/getUIFlags');

const hasUnreadNotifications = computed(
  () => Number(notificationMetadata.value?.unreadCount) > 0
);

const showEmptyResult = computed(
  () => !uiFlags.value.isFetching && records.value.length === 0
);

const onBellClick = (toggle, isOpen) => {
  if (!isOpen) {
    store.dispatch('notifications/get', { page: 1 });
  }
  toggle();
};

const onMarkAllDoneClick = () => {
  useTrack(ACCOUNT_EVENTS.MARK_AS_READ_NOTIFICATIONS);
  store.dispatch('notifications/readAll');
};

const conversationTitle = notificationItem => {
  if (notificationItem.primary_actor) {
    return `#${notificationItem.primary_actor.id}`;
  }
  return t('NOTIFICATIONS_PAGE.DELETE_TITLE');
};

const onNotificationClick = notificationItem => {
  const conversationId = notificationItem.primary_actor?.id;
  if (!conversationId) return;

  const {
    primary_actor_id: primaryActorId,
    primary_actor_type: primaryActorType,
    notification_type: notificationType,
  } = notificationItem;

  useTrack(ACCOUNT_EVENTS.OPEN_CONVERSATION_VIA_NOTIFICATION, {
    notificationType,
  });

  store.dispatch('notifications/read', {
    id: notificationItem.id,
    primaryActorId,
    primaryActorType,
    unreadCount: notificationMetadata.value.unreadCount,
  });

  router.push(
    accountScopedRoute('inbox_conversation', {
      conversation_id: conversationId,
    })
  );

  dropdownRef.value?.closeMenu?.();
};

const onShowAllClick = () => {
  router.push(accountScopedRoute('notifications_index'));
  dropdownRef.value?.closeMenu?.();
};
</script>

<template>
  <DropdownContainer ref="dropdownRef" class="relative">
    <template #trigger="{ toggle, isOpen }">
      <button
        type="button"
        :title="t('SIDEBAR.NOTIFICATIONS')"
        class="relative size-10 rounded-full bg-n-glass-strong border border-n-border-glass backdrop-blur-glass-rail backdrop-saturate-glass shadow-pill-soft text-n-text-body inline-flex items-center justify-center transition-all duration-150 hover:bg-n-glass-pane hover:border-n-border-glass"
        @click="onBellClick(toggle, isOpen)"
      >
        <span class="i-lucide-bell size-[18px]" />
        <span
          v-if="hasUnreadNotifications"
          class="absolute top-2 ltr:right-[9px] rtl:left-[9px] size-2 rounded-full bg-n-ruby-9 border-2 border-n-glass-strong"
        />
      </button>
    </template>
    <DropdownBody
      class="z-50 top-full mt-2 ltr:right-0 rtl:left-0 w-[min(24rem,calc(100vw-1.5rem))] !gap-0 !py-0 !px-0"
    >
      <li class="list-none w-full">
        <div
          class="flex max-h-[min(28rem,calc(100vh-6rem))] flex-col border-b border-n-border-glass-soft"
        >
          <div
            class="flex shrink-0 items-center justify-between gap-2 border-b border-n-border-glass-soft px-3 py-2.5"
          >
            <h2 class="text-base font-medium text-n-text-display">
              {{ t('NOTIFICATIONS_PAGE.HEADER') }}
            </h2>
            <NextButton
              v-if="notificationMetadata.unreadCount"
              type="button"
              sm
              :label="t('NOTIFICATIONS_PAGE.MARK_ALL_DONE')"
              :is-loading="uiFlags.isUpdating"
              @click="onMarkAllDoneClick"
            />
          </div>

          <div
            v-if="uiFlags.isFetching"
            class="flex flex-col items-center justify-center gap-2 px-3 py-8 text-n-text-body"
          >
            <Spinner />
            <span class="text-sm">{{
              t('NOTIFICATIONS_PAGE.LIST.LOADING_MESSAGE')
            }}</span>
          </div>

          <div
            v-else-if="showEmptyResult"
            class="px-3 py-8 text-center text-sm text-n-text-body"
          >
            {{ t('NOTIFICATIONS_PAGE.LIST.404') }}
          </div>

          <ul v-else class="m-0 list-none overflow-y-auto p-0" role="list">
            <li
              v-for="notificationItem in records"
              :key="notificationItem.id"
              class="border-b border-n-border-glass-soft last:border-b-0"
            >
              <button
                type="button"
                class="flex w-full cursor-pointer gap-2 px-3 py-2.5 text-left transition-colors hover:bg-n-slate-3"
                :class="{
                  'font-semibold': notificationItem.read_at === null,
                }"
                @click="onNotificationClick(notificationItem)"
              >
                <div
                  class="flex min-w-0 flex-1 flex-col gap-0.5 overflow-hidden"
                >
                  <span class="text-sm text-n-text-display">
                    {{ conversationTitle(notificationItem) }}
                  </span>
                  <span
                    class="truncate text-sm text-n-text-display"
                    :title="notificationItem.push_message_title"
                  >
                    {{ notificationItem.push_message_title }}
                  </span>
                  <span class="text-xs text-n-text-body">
                    {{
                      t(
                        `NOTIFICATIONS_PAGE.TYPE_LABEL.${notificationItem.notification_type}`
                      )
                    }}
                  </span>
                </div>
                <div
                  class="flex shrink-0 flex-col items-end justify-start gap-1"
                >
                  <Avatar
                    v-if="notificationItem.primary_actor?.meta?.assignee"
                    :src="
                      notificationItem.primary_actor.meta.assignee.thumbnail
                    "
                    :size="28"
                    :name="notificationItem.primary_actor.meta.assignee.name"
                    rounded-full
                  />
                  <span class="text-xs text-n-text-body">
                    {{ dynamicTime(notificationItem.last_activity_at) }}
                  </span>
                  <span
                    v-if="!notificationItem.read_at"
                    class="size-2.5 shrink-0 rounded-full bg-n-brand"
                    aria-hidden="true"
                  />
                </div>
              </button>
            </li>
          </ul>

          <div class="shrink-0 border-t border-n-border-glass-soft px-3 py-2">
            <button
              type="button"
              class="text-sm font-medium text-n-blue-11 hover:text-n-blue-11/90"
              @click="onShowAllClick"
            >
              {{
                t('NOTIFICATIONS_PAGE.UNREAD_NOTIFICATION.ALL_NOTIFICATIONS')
              }}
            </button>
          </div>
        </div>
      </li>
    </DropdownBody>
  </DropdownContainer>
</template>
