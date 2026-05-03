<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

import {
  isAConversationRoute,
  isAInboxViewRoute,
  getConversationDashboardRoute,
} from '../../../../helper/routeHelpers';

import Avatar from 'next/avatar/Avatar.vue';
import SocialIcons from './SocialIcons.vue';
import EditContact from './EditContact.vue';
import ContactMergeModal from 'dashboard/modules/contact/ContactMergeModal.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import VoiceCallButton from 'dashboard/components-next/Contacts/VoiceCallButton.vue';

const props = defineProps({
  contact: {
    type: Object,
    default: () => ({}),
  },
  showAvatar: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['panelClose']);

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();
const { isAdmin } = useAdmin();

const uiFlags = useMapGetter('contacts/getUIFlags');

const showEditModal = ref(false);
const showDeleteModal = ref(false);
const mergeModal = ref(null);

const additionalAttributes = computed(
  () => props.contact.additional_attributes || {}
);

const contactProfileLink = computed(
  () => `/app/accounts/${route.params.accountId}/contacts/${props.contact.id}`
);

const findCountryFlag = (countryCode, cityAndCountry) => {
  try {
    if (!countryCode) return `${cityAndCountry} 🌎`;
    const code = countryCode.toLowerCase();
    return `${cityAndCountry} <span class="fi fi-${code} size-3.5"></span>`;
  } catch (error) {
    return '';
  }
};

const location = computed(() => {
  const {
    country = '',
    city = '',
    country_code: countryCode,
  } = additionalAttributes.value;
  const cityAndCountry = [city, country].filter(Boolean).join(', ');
  if (!cityAndCountry) return '';
  return findCountryFlag(countryCode, cityAndCountry);
});

const socialProfiles = computed(() => {
  const {
    social_profiles: profiles,
    screen_name: twitterScreenName,
    social_telegram_user_name: telegramUsername,
  } = additionalAttributes.value;

  const telegram = profiles?.telegram || telegramUsername || '';
  const twitter = profiles?.twitter || twitterScreenName || '';

  return { ...(profiles || {}), twitter, telegram };
});

const subtitle = computed(() => {
  const company = additionalAttributes.value.company_name;
  const desc = additionalAttributes.value.description;
  return company || desc || '';
});

const infoRows = computed(() => {
  const rows = [];
  if (props.contact.email) {
    rows.push({
      key: 'email',
      icon: 'i-lucide-mail',
      label: t('CONTACT_PANEL.EMAIL_ADDRESS'),
      value: props.contact.email,
      href: `mailto:${props.contact.email}`,
      copy: true,
    });
  }
  if (props.contact.phone_number) {
    rows.push({
      key: 'phone',
      icon: 'i-lucide-phone',
      label: t('CONTACT_PANEL.PHONE_NUMBER'),
      value: props.contact.phone_number,
      href: `tel:${props.contact.phone_number}`,
      copy: true,
    });
  }
  if (props.contact.identifier) {
    rows.push({
      key: 'identifier',
      icon: 'i-lucide-fingerprint',
      label: t('CONTACT_PANEL.IDENTIFIER'),
      value: props.contact.identifier,
      copy: true,
    });
  }
  if (additionalAttributes.value.company_name) {
    rows.push({
      key: 'company',
      icon: 'i-lucide-building-2',
      label: t('CONTACT_PANEL.COMPANY'),
      value: additionalAttributes.value.company_name,
    });
  }
  const loc = location.value || additionalAttributes.value.location;
  if (loc) {
    rows.push({
      key: 'location',
      icon: 'i-lucide-map-pin',
      label: t('CONTACT_PANEL.LOCATION'),
      value: loc,
      isHtml: true,
    });
  }
  return rows;
});

const confirmDeleteMessage = computed(() => ` ${props.contact.name}?`);

const toggleEditModal = () => {
  showEditModal.value = !showEditModal.value;
};

const openComposeConversationModal = toggleFn => {
  toggleFn();
  emitter.emit(BUS_EVENTS.NEW_CONVERSATION_MODAL, true);
};

const closeComposeConversationModal = () => {
  emitter.emit(BUS_EVENTS.NEW_CONVERSATION_MODAL, false);
};

const toggleDeleteModal = () => {
  showDeleteModal.value = !showDeleteModal.value;
};

const closeDelete = () => {
  showDeleteModal.value = false;
  showEditModal.value = false;
};

const deleteContact = async ({ id }) => {
  try {
    await store.dispatch('contacts/delete', id);
    emit('panelClose');
    useAlert(t('DELETE_CONTACT.API.SUCCESS_MESSAGE'));

    if (isAConversationRoute(route.name)) {
      router.push({ name: getConversationDashboardRoute(route.name) });
    } else if (isAInboxViewRoute(route.name)) {
      router.push({ name: 'inbox_view' });
    } else if (route.name !== 'contacts_dashboard') {
      router.push({ name: 'contacts_dashboard' });
    }
  } catch (error) {
    useAlert(error.message || t('DELETE_CONTACT.API.ERROR_MESSAGE'));
  }
};

const confirmDeletion = () => {
  deleteContact(props.contact);
  closeDelete();
};

const openMergeModal = () => {
  mergeModal.value?.open();
};

const onCopyValue = async value => {
  if (!value) return;
  await copyTextToClipboard(value);
  useAlert(t('CONTACT_PANEL.COPY_SUCCESSFUL'));
};

watch(
  () => props.contact.id,
  id => {
    if (id) store.dispatch('contacts/fetchContactableInbox', id);
  },
  { immediate: true }
);
</script>

<template>
  <div
    class="contact--profile relative w-full px-4 pt-4 pb-4 border-b border-n-border-hairline"
  >
    <!-- Header: avatar + name/meta + external link -->
    <div class="flex items-center gap-2.5 mb-3.5">
      <Avatar
        v-if="showAvatar"
        :src="contact.thumbnail"
        :name="contact.name"
        :status="contact.availability_status"
        :size="44"
        hide-offline-status
      />
      <div class="flex-1 min-w-0">
        <h3
          class="font-interDisplay text-[15px] font-bold tracking-tight text-n-text-display capitalize truncate m-0"
        >
          {{ contact.name }}
        </h3>
        <div
          v-if="subtitle || contact.created_at"
          class="text-[11px] text-n-text-muted mt-0.5 truncate"
        >
          <span v-if="subtitle">{{ subtitle }}</span>
          <span v-else-if="contact.created_at">
            {{ $t('CONTACT_PANEL.CREATED_AT_LABEL') }}
            {{ dynamicTime(contact.created_at) }}
          </span>
        </div>
      </div>
      <a
        v-tooltip.left="$t('CONTACT_PANEL.VIEW_PROFILE')"
        :href="contactProfileLink"
        target="_blank"
        rel="noopener nofollow noreferrer"
        class="size-7 rounded-[10px] bg-n-glass-soft text-n-text-body hover:bg-n-alpha-2 inline-flex items-center justify-center transition-colors flex-shrink-0"
      >
        <span class="i-lucide-external-link size-3.5" />
      </a>
    </div>

    <!-- Info rows -->
    <div v-if="infoRows.length" class="flex flex-col gap-1 mb-3">
      <component
        :is="row.href ? 'a' : 'div'"
        v-for="row in infoRows"
        :key="row.key"
        :href="row.href || undefined"
        class="group flex items-center gap-2.5 px-1 py-1.5 rounded-[10px] hover:bg-n-alpha-1 transition-colors"
      >
        <span
          class="size-3 text-n-text-muted flex-shrink-0"
          :class="[row.icon]"
        />
        <div class="flex-1 min-w-0">
          <div
            class="text-[10.5px] text-n-text-muted uppercase tracking-wide font-semibold leading-none"
          >
            {{ row.label }}
          </div>
          <div
            v-if="row.isHtml"
            v-dompurify-html="row.value"
            class="text-[12.5px] text-n-text-display mt-1 font-medium truncate"
          />
          <div
            v-else
            class="text-[12.5px] text-n-text-display mt-1 font-medium truncate"
            :title="row.value"
          >
            {{ row.value }}
          </div>
        </div>
        <button
          v-if="row.copy"
          type="button"
          class="size-6 rounded-md inline-flex items-center justify-center text-n-text-muted opacity-0 group-hover:opacity-100 hover:bg-n-alpha-2 transition"
          @click.prevent.stop="onCopyValue(row.value)"
        >
          <span class="i-lucide-clipboard size-3" />
        </button>
      </component>
    </div>

    <!-- Social profiles -->
    <SocialIcons
      v-if="
        socialProfiles.telegram ||
        socialProfiles.twitter ||
        socialProfiles.instagram ||
        socialProfiles.vk
      "
      :social-profiles="socialProfiles"
      class="!mt-0 !mb-3"
    />

    <!-- Action bar -->
    <div class="flex items-center gap-1.5 p-1.5 bg-n-alpha-1 rounded-[14px]">
      <ComposeConversation
        :contact-id="String(contact.id)"
        is-modal
        @close="closeComposeConversationModal"
      >
        <template #trigger="{ toggle }">
          <button
            v-tooltip.top="$t('CONTACT_PANEL.NEW_MESSAGE')"
            type="button"
            class="flex-1 h-[30px] rounded-[10px] bg-n-glass-strong text-n-text-body inline-flex items-center justify-center hover:text-n-text-display hover:shadow-pill-soft transition"
            @click="openComposeConversationModal(toggle)"
          >
            <span class="i-lucide-message-circle size-3.5" />
          </button>
        </template>
      </ComposeConversation>
      <VoiceCallButton
        v-if="contact.phone_number"
        :phone="contact.phone_number"
        :contact-id="contact.id"
        :tooltip-label="$t('CONTACT_PANEL.CALL')"
        icon="i-lucide-phone"
        class="!flex-1 !h-[30px] !w-auto !min-w-0 !rounded-[10px] !bg-n-glass-strong !text-n-text-body !shadow-none hover:!text-n-text-display hover:!shadow-pill-soft !outline-transparent"
        solid
        slate
        sm
      />
      <button
        v-tooltip.top="$t('EDIT_CONTACT.BUTTON_LABEL')"
        type="button"
        class="flex-1 h-[30px] rounded-[10px] bg-n-glass-strong text-n-text-body inline-flex items-center justify-center hover:text-n-text-display hover:shadow-pill-soft transition"
        @click="toggleEditModal"
      >
        <span class="i-lucide-pen-line size-3.5" />
      </button>
      <button
        v-tooltip.top="$t('CONTACT_PANEL.MERGE_CONTACT')"
        type="button"
        :disabled="uiFlags.isMerging"
        class="flex-1 h-[30px] rounded-[10px] bg-n-glass-strong text-n-text-body inline-flex items-center justify-center hover:text-n-text-display hover:shadow-pill-soft transition disabled:opacity-50"
        @click="openMergeModal"
      >
        <span class="i-lucide-git-merge size-3.5" />
      </button>
      <button
        v-if="isAdmin"
        v-tooltip.top="$t('DELETE_CONTACT.BUTTON_LABEL')"
        type="button"
        :disabled="uiFlags.isDeleting"
        class="flex-1 h-[30px] rounded-[10px] bg-n-glass-strong text-n-ruby-9 inline-flex items-center justify-center hover:shadow-pill-soft transition disabled:opacity-50"
        @click="toggleDeleteModal"
      >
        <span class="i-lucide-trash-2 size-3.5" />
      </button>
    </div>

    <EditContact
      v-if="showEditModal"
      :show="showEditModal"
      :contact="contact"
      @cancel="toggleEditModal"
    />
    <ContactMergeModal ref="mergeModal" :primary-contact="contact" />

    <woot-delete-modal
      v-if="showDeleteModal"
      v-model:show="showDeleteModal"
      :on-close="closeDelete"
      :on-confirm="confirmDeletion"
      :title="$t('DELETE_CONTACT.CONFIRM.TITLE')"
      :message="$t('DELETE_CONTACT.CONFIRM.MESSAGE')"
      :message-value="confirmDeleteMessage"
      :confirm-text="$t('DELETE_CONTACT.CONFIRM.YES')"
      :reject-text="$t('DELETE_CONTACT.CONFIRM.NO')"
    />
  </div>
</template>
