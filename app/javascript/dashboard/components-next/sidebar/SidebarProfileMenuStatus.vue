<script setup>
import { computed, h } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import wootConstants from 'dashboard/constants/globals';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useImpersonation } from 'dashboard/composables/useImpersonation';

import {
  DropdownContainer,
  DropdownBody,
  DropdownSection,
  DropdownItem,
} from 'next/dropdown-menu/base';
import Icon from 'next/icon/Icon.vue';
import Button from 'next/button/Button.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';

const { t } = useI18n();
const store = useStore();
const currentUserAvailability = useMapGetter('getCurrentUserAvailability');
const currentAccountId = useMapGetter('getCurrentAccountId');
const currentUserAutoOffline = useMapGetter('getCurrentUserAutoOffline');

const { isImpersonating } = useImpersonation();

const { AVAILABILITY_STATUS_KEYS } = wootConstants;
const statusList = computed(() => {
  return [
    t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.ONLINE'),
    t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.BUSY'),
    t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.OFFLINE'),
  ];
});

const statusColors = ['bg-n-teal-9', 'bg-n-amber-9', 'bg-n-slate-9'];

const availabilityStatuses = computed(() => {
  return statusList.value.map((statusLabel, index) => ({
    label: statusLabel,
    value: AVAILABILITY_STATUS_KEYS[index],
    color: statusColors[index],
    icon: h('span', { class: [statusColors[index], 'size-[12px] rounded'] }),
    active: currentUserAvailability.value === AVAILABILITY_STATUS_KEYS[index],
  }));
});

const activeStatus = computed(() => {
  return availabilityStatuses.value.find(status => status.active);
});

const autoOfflineToggle = computed({
  get: () => currentUserAutoOffline.value,
  set: autoOffline => {
    store.dispatch('updateAutoOffline', {
      accountId: currentAccountId.value,
      autoOffline,
    });
  },
});

function changeAvailabilityStatus(availability) {
  if (isImpersonating.value) {
    useAlert(t('PROFILE_SETTINGS.FORM.AVAILABILITY.IMPERSONATING_ERROR'));
    return;
  }
  try {
    store.dispatch('updateAvailability', {
      availability,
      account_id: currentAccountId.value,
    });
  } catch (error) {
    useAlert(t('PROFILE_SETTINGS.FORM.AVAILABILITY.SET_AVAILABILITY_ERROR'));
  }
}
</script>

<template>
  <DropdownSection
    :title="$t('SIDEBAR.SET_YOUR_AVAILABILITY')"
    class="[&>ul]:overflow-visible !px-0"
  >
    <li class="n-dropdown-item col-span-full !p-0 !block list-none">
      <div
        class="mx-1.5 mb-2 rounded-xl border border-n-border-glass-soft bg-n-alpha-2/50 p-3 space-y-3"
      >
        <div class="flex items-center justify-end gap-2 min-w-0">
          <DropdownContainer>
            <template #trigger="{ toggle }">
              <Button
                size="sm"
                color="slate"
                variant="faded"
                class="w-full min-w-0 max-w-full sm:max-w-[14rem]"
                icon="i-lucide-chevron-down"
                trailing-icon
                @click="toggle"
              >
                <div
                  class="flex gap-1.5 items-center min-w-0 justify-center text-sm"
                >
                  <div
                    class="p-0.5 flex-shrink-0 rounded-sm ring-1 ring-n-border-glass-soft"
                  >
                    <div
                      class="size-2 rounded-sm"
                      :class="activeStatus.color"
                    />
                  </div>
                  <span class="truncate">{{ activeStatus.label }}</span>
                </div>
              </Button>
            </template>
            <DropdownBody class="min-w-36 z-20" strong>
              <DropdownItem
                v-for="status in availabilityStatuses"
                :key="status.value"
                :label="status.label"
                :icon="status.icon"
                class="cursor-pointer"
                @click="changeAvailabilityStatus(status.value)"
              />
            </DropdownBody>
          </DropdownContainer>
        </div>
        <div
          class="flex items-center justify-between gap-3 pt-2 border-t border-n-border-glass-soft/70"
        >
          <div
            class="flex items-center gap-1.5 min-w-0 text-xs text-n-text-body"
          >
            <span class="leading-snug">{{
              $t('SIDEBAR.SET_AUTO_OFFLINE.TEXT')
            }}</span>
            <Icon
              v-tooltip.top="$t('SIDEBAR.SET_AUTO_OFFLINE.INFO_SHORT')"
              icon="i-lucide-info"
              class="size-3.5 text-n-text-body/60 flex-shrink-0"
            />
          </div>
          <ToggleSwitch v-model="autoOfflineToggle" class="flex-shrink-0" />
        </div>
      </div>
    </li>
  </DropdownSection>
</template>
