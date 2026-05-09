<script setup>
import { h, ref, computed, onMounted } from 'vue';
import { provideSidebarContext, useSidebarResize } from './provider';
import { useAccount } from 'dashboard/composables/useAccount';
import { useKbd } from 'dashboard/composables/utils/useKbd';
import { useMapGetter } from 'dashboard/composables/store';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useSidebarKeyboardShortcuts } from './useSidebarKeyboardShortcuts';
import { vOnClickOutside } from '@vueuse/components';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useWindowSize, useEventListener } from '@vueuse/core';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

import Button from 'dashboard/components-next/button/Button.vue';
import SidebarGroup from './SidebarGroup.vue';
import SidebarChangelogCard from './SidebarChangelogCard.vue';
import SidebarChangelogButton from './SidebarChangelogButton.vue';
import ChannelLeaf from './ChannelLeaf.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';

const props = defineProps({
  isMobileSidebarOpen: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'closeKeyShortcutModal',
  'openKeyShortcutModal',
  'closeMobileSidebar',
]);

const { accountScopedRoute, isOnChatwootCloud, route } = useAccount();
const store = useStore();
const searchShortcut = useKbd([`$mod`, 'k']);
const { t } = useI18n();

const isACustomBrandedInstance = useMapGetter(
  'globalConfig/isACustomBrandedInstance'
);
const isRTL = useMapGetter('accounts/isRTL');

const { width: windowWidth } = useWindowSize();
const isMobile = computed(() => windowWidth.value < 768);

const accountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const hasAdvancedAssignment = computed(() => {
  return isFeatureEnabledonAccount.value(
    accountId.value,
    FEATURE_FLAGS.ADVANCED_ASSIGNMENT
  );
});

const isHelpCenterEnabled = computed(() =>
  isFeatureEnabledonAccount.value(accountId.value, FEATURE_FLAGS.HELP_CENTER)
);

const toggleShortcutModalFn = show => {
  if (show) {
    emit('openKeyShortcutModal');
  } else {
    emit('closeKeyShortcutModal');
  }
};

useSidebarKeyboardShortcuts(toggleShortcutModalFn);

const {
  sidebarWidth,
  isCollapsed,
  setSidebarWidth,
  saveWidth,
  snapToCollapsed,
  snapToExpanded,
  COLLAPSED_THRESHOLD,
} = useSidebarResize();

// On mobile, sidebar is always expanded (flyout mode)
const isEffectivelyCollapsed = computed(
  () => !isMobile.value && isCollapsed.value
);

// Resize handle logic
const isResizing = ref(false);
const startX = ref(0);
const startWidth = ref(0);

provideSidebarContext({
  isCollapsed: isEffectivelyCollapsed,
  sidebarWidth,
  isResizing,
  snapToExpanded,
});

const onToggleSidebar = () => {
  if (isCollapsed.value) {
    snapToExpanded();
  } else {
    snapToCollapsed();
  }
};

// Get clientX from mouse or touch event
const getClientX = event =>
  event.touches ? event.touches[0].clientX : event.clientX;

const onResizeStart = event => {
  isResizing.value = true;
  startX.value = getClientX(event);
  startWidth.value = sidebarWidth.value;
  Object.assign(document.body.style, {
    cursor: 'col-resize',
    userSelect: 'none',
  });
  // Prevent default to avoid scrolling on touch
  event.preventDefault();
};

const onResizeMove = event => {
  if (!isResizing.value) return;

  const delta = isRTL.value
    ? startX.value - getClientX(event)
    : getClientX(event) - startX.value;
  setSidebarWidth(startWidth.value + delta);
};

const onResizeEnd = () => {
  if (!isResizing.value) return;

  isResizing.value = false;
  Object.assign(document.body.style, { cursor: '', userSelect: '' });

  // Snap to collapsed state if below threshold
  if (sidebarWidth.value < COLLAPSED_THRESHOLD) {
    snapToCollapsed();
  } else {
    saveWidth();
  }
};

const onResizeHandleDoubleClick = () => {
  if (isCollapsed.value) snapToExpanded();
  else snapToCollapsed();
};

// Support both mouse and touch events
useEventListener(document, 'mousemove', onResizeMove);
useEventListener(document, 'mouseup', onResizeEnd);
useEventListener(document, 'touchmove', onResizeMove, { passive: false });
useEventListener(document, 'touchend', onResizeEnd);

const inboxes = useMapGetter('inboxes/getInboxes');
const labels = useMapGetter('labels/getLabelsOnSidebar');
const teams = useMapGetter('teams/getMyTeams');
const contactCustomViews = useMapGetter('customViews/getContactCustomViews');
const conversationCustomViews = useMapGetter(
  'customViews/getConversationCustomViews'
);
const integrations = useMapGetter('integrations/getAppIntegrations');

onMounted(() => {
  store.dispatch('labels/get');
  store.dispatch('inboxes/get');
  store.dispatch('notifications/unReadCount');
  store.dispatch('teams/get');
  store.dispatch('attributes/get');
  store.dispatch('customViews/get', 'conversation');
  store.dispatch('customViews/get', 'contact');
  store.dispatch('integrations/get');
});

const sortedInboxes = computed(() =>
  inboxes.value.slice().sort((a, b) => a.name.localeCompare(b.name))
);

const closeMobileSidebar = () => {
  if (!props.isMobileSidebarOpen) return;
  emit('closeMobileSidebar');
};

const onComposeOpen = toggleFn => {
  toggleFn();
  emitter.emit(BUS_EVENTS.NEW_CONVERSATION_MODAL, true);
};

const onComposeClose = () => {
  emitter.emit(BUS_EVENTS.NEW_CONVERSATION_MODAL, false);
};

const newReportRoutes = () => [
  {
    name: 'Reports Agent',
    label: t('SIDEBAR.REPORTS_AGENT'),
    to: accountScopedRoute('agent_reports_index'),
    activeOn: ['agent_reports_show'],
  },
  {
    name: 'Reports Agent Activity',
    label: t('SIDEBAR.AGENT_ACTIVITY'),
    to: accountScopedRoute('agent_activity'),
  },
  {
    name: 'Reports Label',
    label: t('SIDEBAR.REPORTS_LABEL'),
    to: accountScopedRoute('label_reports_index'),
  },
  {
    name: 'Reports Inbox',
    label: t('SIDEBAR.REPORTS_INBOX'),
    to: accountScopedRoute('inbox_reports_index'),
    activeOn: ['inbox_reports_show'],
  },
  {
    name: 'Reports Team',
    label: t('SIDEBAR.REPORTS_TEAM'),
    to: accountScopedRoute('team_reports_index'),
    activeOn: ['team_reports_show'],
  },
];

const reportRoutes = computed(() => newReportRoutes());
const captainInsightsRoute = computed(() => {
  const assistantId = route.params.assistantId;

  if (assistantId) {
    return accountScopedRoute('captain_assistants_insights_index', {
      assistantId,
    });
  }

  return accountScopedRoute('captain_assistants_index', {
    navigationPath: 'captain_assistants_insights_index',
  });
});

const isBookingManagerEnabled = computed(() =>
  integrations.value.some(
    integration => integration.id === 'booking_manager' && integration.enabled
  )
);

const menuItems = computed(() => {
  const scheduleGroup = isBookingManagerEnabled.value
    ? {
        name: 'Schedule',
        label: t('SIDEBAR.SCHEDULE'),
        icon: 'i-lucide-calendar-clock',
        children: [
          {
            name: 'Schedule Calendar',
            label: t('SIDEBAR.SCHEDULE_CALENDAR'),
            to: accountScopedRoute('services_schedule'),
            activeOn: ['services_schedule', 'services_schedule_settings'],
          },
          {
            name: 'Schedule Providers',
            label: t('SIDEBAR.SCHEDULE_PROVIDERS'),
            to: accountScopedRoute('services_providers'),
            activeOn: ['services_providers', 'services_list'],
          },
          {
            name: 'Schedule Services',
            label: t('SIDEBAR.SCHEDULE_SERVICES'),
            to: accountScopedRoute('services_services'),
            activeOn: ['services_services'],
          },
        ],
      }
    : null;

  return [
    {
      name: 'Conversation',
      label: t('SIDEBAR.CONVERSATIONS'),
      icon: 'i-lucide-message-circle',
      children: [
        {
          name: 'All',
          label: t('SIDEBAR.ALL_CONVERSATIONS'),
          activeOn: ['inbox_conversation'],
          to: accountScopedRoute('home'),
        },
        {
          name: 'Mentions',
          label: t('SIDEBAR.MENTIONED_CONVERSATIONS'),
          activeOn: ['conversation_through_mentions'],
          to: accountScopedRoute('conversation_mentions'),
        },
        {
          name: 'Folders',
          label: t('SIDEBAR.CUSTOM_VIEWS_FOLDER'),
          icon: 'i-lucide-folder',
          activeOn: ['conversations_through_folders'],
          children: conversationCustomViews.value.map(view => ({
            name: `${view.name}-${view.id}`,
            label: view.name,
            to: accountScopedRoute('folder_conversations', { id: view.id }),
          })),
        },
        {
          name: 'Teams',
          label: t('SIDEBAR.TEAMS'),
          icon: 'i-lucide-users',
          activeOn: ['conversations_through_team'],
          children: teams.value.map(team => ({
            name: `${team.name}-${team.id}`,
            label: team.name,
            to: accountScopedRoute('team_conversations', { teamId: team.id }),
          })),
        },
        {
          name: 'Channels',
          label: t('SIDEBAR.CHANNELS'),
          icon: 'i-lucide-mailbox',
          activeOn: ['conversation_through_inbox'],
          children: sortedInboxes.value.map(inbox => ({
            name: `${inbox.name}-${inbox.id}`,
            label: inbox.name,
            icon: h(ChannelIcon, { inbox, class: 'size-[16px]' }),
            to: accountScopedRoute('inbox_dashboard', { inbox_id: inbox.id }),
            component: leafProps =>
              h(ChannelLeaf, {
                label: leafProps.label,
                active: leafProps.active,
                inbox,
              }),
          })),
        },
        {
          name: 'Labels',
          label: t('SIDEBAR.LABELS'),
          icon: 'i-lucide-tag',
          activeOn: ['conversations_through_label'],
          children: labels.value.map(label => ({
            name: `${label.title}-${label.id}`,
            label: label.title,
            icon: h('span', {
              class: `size-[8px] rounded-sm`,
              style: { backgroundColor: label.color },
            }),
            to: accountScopedRoute('label_conversations', {
              label: label.title,
            }),
          })),
        },
      ],
    },
    {
      name: 'Captain',
      icon: 'i-woot-captain',
      label: t('SIDEBAR.CAPTAIN'),
      activeOn: ['captain_assistants_create_index'],
      children: [
        {
          name: 'Knowledge',
          label: t('SIDEBAR.CAPTAIN_KNOWLEDGE'),
          activeOn: [
            'captain_assistants_knowledge_index',
            'captain_assistants_responses_index',
            'captain_assistants_responses_pending',
            'captain_assistants_documents_index',
            'captain_assistants_scenarios_index',
          ],
          to: accountScopedRoute('captain_assistants_index', {
            navigationPath: 'captain_assistants_knowledge_index',
          }),
        },
        {
          name: 'Playground',
          label: t('SIDEBAR.CAPTAIN_PLAYGROUND'),
          activeOn: ['captain_assistants_playground_index'],
          to: accountScopedRoute('captain_assistants_index', {
            navigationPath: 'captain_assistants_playground_index',
          }),
        },
        {
          name: 'Insights',
          label: t('SIDEBAR.CAPTAIN_INSIGHTS'),
          activeOn: ['captain_assistants_insights_index'],
          to: captainInsightsRoute.value,
        },
        {
          name: 'Settings',
          label: t('SIDEBAR.CAPTAIN_SETTINGS'),
          activeOn: [
            'captain_assistants_settings_index',
            'captain_tools_index',
            'captain_assistants_inboxes_index',
            'captain_assistants_guidelines_index',
            'captain_assistants_guardrails_index',
          ],
          to: accountScopedRoute('captain_assistants_index', {
            navigationPath: 'captain_assistants_settings_index',
          }),
        },
      ],
    },
    {
      name: 'Contacts',
      label: t('SIDEBAR.CONTACTS'),
      icon: 'i-lucide-contact',
      children: [
        {
          name: 'All Contacts',
          label: t('SIDEBAR.ALL_CONTACTS'),
          to: accountScopedRoute(
            'contacts_dashboard_index',
            {},
            { page: 1, search: undefined }
          ),
          activeOn: ['contacts_dashboard_index', 'contacts_edit'],
        },
        {
          name: 'Active',
          label: t('SIDEBAR.ACTIVE'),
          to: accountScopedRoute('contacts_dashboard_active'),
          activeOn: ['contacts_dashboard_active'],
        },
        {
          name: 'Segments',
          icon: 'i-lucide-group',
          label: t('SIDEBAR.CUSTOM_VIEWS_SEGMENTS'),
          children: contactCustomViews.value.map(view => ({
            name: `${view.name}-${view.id}`,
            label: view.name,
            to: accountScopedRoute(
              'contacts_dashboard_segments_index',
              { segmentId: view.id },
              { page: 1 }
            ),
            activeOn: [
              'contacts_dashboard_segments_index',
              'contacts_edit_segment',
            ],
          })),
        },
        {
          name: 'Tagged With',
          icon: 'i-lucide-tag',
          label: t('SIDEBAR.TAGGED_WITH'),
          children: labels.value.map(label => ({
            name: `${label.title}-${label.id}`,
            label: label.title,
            icon: h('span', {
              class: `size-[8px] rounded-sm`,
              style: { backgroundColor: label.color },
            }),
            to: accountScopedRoute(
              'contacts_dashboard_labels_index',
              { label: label.title },
              { page: 1, search: undefined }
            ),
            activeOn: [
              'contacts_dashboard_labels_index',
              'contacts_edit_label',
            ],
          })),
        },
      ],
    },
    ...(scheduleGroup ? [scheduleGroup] : []),
    {
      name: 'Reports',
      label: t('SIDEBAR.REPORTS'),
      icon: 'i-lucide-chart-spline',
      children: [
        {
          name: 'Report Overview',
          label: t('SIDEBAR.REPORTS_OVERVIEW'),
          to: accountScopedRoute('account_overview_reports'),
        },
        {
          name: 'Report Conversation',
          label: t('SIDEBAR.REPORTS_CONVERSATION'),
          to: accountScopedRoute('conversation_reports'),
        },
        ...reportRoutes.value,
        {
          name: 'Reports CSAT',
          label: t('SIDEBAR.CSAT'),
          to: accountScopedRoute('csat_reports'),
        },
        {
          name: 'Reports SLA',
          label: t('SIDEBAR.REPORTS_SLA'),
          to: accountScopedRoute('sla_reports'),
        },
        {
          name: 'Reports Bot',
          label: t('SIDEBAR.REPORTS_BOT'),
          to: accountScopedRoute('bot_reports'),
        },
        {
          name: 'Reports Segments',
          label: t('SIDEBAR.REPORTS_SEGMENTS'),
          to: accountScopedRoute('segment_reports'),
        },
      ],
    },
    {
      name: 'Mailings',
      icon: 'i-lucide-send',
      label: t('SIDEBAR.MAILINGS'),
      children: [
        {
          name: 'Mailings Templates',
          label: t('SIDEBAR.MAILINGS_TEMPLATES'),
          activeOn: [
            'notification_templates_index',
            'notification_templates_new',
            'notification_templates_edit',
            'notification_templates_marketing',
          ],
          to: accountScopedRoute('notification_templates_index'),
        },
        {
          name: 'Mailings Statistics',
          label: t('SIDEBAR.MAILINGS_STATISTICS'),
          activeOn: ['notification_templates_statistics'],
          to: accountScopedRoute('notification_templates_statistics'),
        },
        {
          name: 'Campaigns',
          label: t('SIDEBAR.CAMPAIGNS'),
          activeOn: ['campaigns_index', 'campaigns_new', 'campaigns_edit'],
          to: accountScopedRoute('campaigns_index'),
        },
      ],
    },
    {
      name: 'Notifications',
      icon: 'i-lucide-bell',
      label: t('SIDEBAR.NOTIFICATIONS'),
      children: [
        {
          name: 'Notifications Templates',
          label: t('SIDEBAR.NOTIFICATIONS_TEMPLATES'),
          activeOn: ['notification_templates_service'],
          to: accountScopedRoute('notification_templates_service'),
        },
        {
          name: 'Notifications Statistics',
          label: t('SIDEBAR.NOTIFICATIONS_STATISTICS'),
          activeOn: ['campaigns_statistics'],
          to: accountScopedRoute('campaigns_statistics'),
        },
      ],
    },
    {
      name: 'Suggestions',
      label: t('SIDEBAR.SUGGESTIONS'),
      icon: 'i-lucide-lightbulb',
      to: accountScopedRoute('suggestions_index'),
    },
    ...(isHelpCenterEnabled.value
      ? [
          {
            name: 'Portals',
            label: t('SIDEBAR.HELP_CENTER.TITLE'),
            icon: 'i-lucide-library-big',
            children: [
              {
                name: 'Articles',
                label: t('SIDEBAR.HELP_CENTER.ARTICLES'),
                activeOn: [
                  'portals_articles_index',
                  'portals_articles_new',
                  'portals_articles_edit',
                ],
                to: accountScopedRoute('portals_index', {
                  navigationPath: 'portals_articles_index',
                }),
              },
              {
                name: 'Categories',
                label: t('SIDEBAR.HELP_CENTER.CATEGORIES'),
                activeOn: [
                  'portals_categories_index',
                  'portals_categories_articles_index',
                  'portals_categories_articles_edit',
                ],
                to: accountScopedRoute('portals_index', {
                  navigationPath: 'portals_categories_index',
                }),
              },
              {
                name: 'Locales',
                label: t('SIDEBAR.HELP_CENTER.LOCALES'),
                activeOn: ['portals_locales_index'],
                to: accountScopedRoute('portals_index', {
                  navigationPath: 'portals_locales_index',
                }),
              },
              {
                name: 'Settings',
                label: t('SIDEBAR.HELP_CENTER.SETTINGS'),
                activeOn: ['portals_settings_index'],
                to: accountScopedRoute('portals_index', {
                  navigationPath: 'portals_settings_index',
                }),
              },
            ],
          },
        ]
      : []),
    {
      name: 'Settings',
      label: t('SIDEBAR.SETTINGS'),
      icon: 'i-lucide-bolt',
      children: [
        {
          name: 'Settings Account Settings',
          label: t('SIDEBAR.ACCOUNT_SETTINGS'),
          icon: 'i-lucide-briefcase',
          to: accountScopedRoute('general_settings_index'),
        },
        {
          name: 'Settings Captain',
          label: t('SIDEBAR.CAPTAIN_AI'),
          icon: 'i-woot-captain',
          to: accountScopedRoute('captain_settings_index'),
        },
        {
          name: 'Settings Agents',
          label: t('SIDEBAR.AGENTS'),
          icon: 'i-lucide-square-user',
          to: accountScopedRoute('agent_list'),
        },
        {
          name: 'Settings Teams',
          label: t('SIDEBAR.TEAMS'),
          icon: 'i-lucide-users',
          activeOn: [
            'settings_teams_list',
            'settings_teams_new',
            'settings_teams_finish',
            'settings_teams_add_agents',
            'settings_teams_show',
            'settings_teams_edit',
            'settings_teams_edit_members',
            'settings_teams_edit_finish',
          ],
          to: accountScopedRoute('settings_teams_list'),
        },
        ...(hasAdvancedAssignment.value
          ? [
              {
                name: 'Settings Agent Assignment',
                label: t('SIDEBAR.AGENT_ASSIGNMENT'),
                icon: 'i-lucide-user-cog',
                activeOn: [
                  'assignment_policy_index',
                  'agent_assignment_policy_index',
                  'agent_assignment_policy_create',
                  'agent_assignment_policy_edit',
                  'agent_capacity_policy_index',
                  'agent_capacity_policy_create',
                  'agent_capacity_policy_edit',
                ],
                to: accountScopedRoute('assignment_policy_index'),
              },
            ]
          : []),
        {
          name: 'Settings Inboxes',
          label: t('SIDEBAR.INBOXES'),
          icon: 'i-lucide-inbox',
          activeOn: [
            'settings_inbox_list',
            'settings_inbox_show',
            'settings_inbox_new',
            'settings_inbox_finish',
            'settings_inboxes_page_channel',
            'settings_inboxes_add_agents',
          ],
          to: accountScopedRoute('settings_inbox_list'),
        },
        {
          name: 'Settings Labels',
          label: t('SIDEBAR.LABELS'),
          icon: 'i-lucide-tags',
          to: accountScopedRoute('labels_list'),
        },
        {
          name: 'Settings Custom Attributes',
          label: t('SIDEBAR.CUSTOM_ATTRIBUTES'),
          icon: 'i-lucide-code',
          to: accountScopedRoute('attributes_list'),
        },
        {
          name: 'Settings Automation',
          label: t('SIDEBAR.AUTOMATION'),
          icon: 'i-lucide-repeat',
          to: accountScopedRoute('automation_list'),
        },
        {
          name: 'Settings Agent Bots',
          label: t('SIDEBAR.AGENT_BOTS'),
          icon: 'i-lucide-bot',
          to: accountScopedRoute('agent_bots'),
        },
        {
          name: 'Settings Macros',
          label: t('SIDEBAR.MACROS'),
          icon: 'i-lucide-toy-brick',
          to: accountScopedRoute('macros_wrapper'),
        },
        {
          name: 'Settings Canned Responses',
          label: t('SIDEBAR.CANNED_RESPONSES'),
          icon: 'i-lucide-message-square-quote',
          to: accountScopedRoute('canned_list'),
        },
        {
          name: 'Settings Integrations',
          label: t('SIDEBAR.INTEGRATIONS'),
          icon: 'i-lucide-blocks',
          to: accountScopedRoute('settings_applications'),
        },
        {
          name: 'Settings Audit Logs',
          label: t('SIDEBAR.AUDIT_LOGS'),
          icon: 'i-lucide-briefcase',
          to: accountScopedRoute('auditlogs_list'),
        },
        {
          name: 'Settings Custom Roles',
          label: t('SIDEBAR.CUSTOM_ROLES'),
          icon: 'i-lucide-shield-plus',
          to: accountScopedRoute('custom_roles_list'),
        },
        {
          name: 'Settings Sla',
          label: t('SIDEBAR.SLA'),
          icon: 'i-lucide-clock-alert',
          to: accountScopedRoute('sla_list'),
        },
        {
          name: 'Conversation Workflow',
          label: t('SIDEBAR.CONVERSATION_WORKFLOW'),
          icon: 'i-lucide-workflow',
          to: accountScopedRoute('conversation_workflow_index'),
        },
        {
          name: 'Settings Notifications',
          label: t('SIDEBAR.NOTIFICATIONS_SETTINGS'),
          icon: 'i-lucide-bell',
          to: accountScopedRoute('notifications_settings'),
        },
        {
          name: 'Settings Security',
          label: t('SIDEBAR.SECURITY'),
          icon: 'i-lucide-shield',
          to: accountScopedRoute('security_settings_index'),
        },
      ],
    },
  ];
});
</script>

<template>
  <aside
    v-on-click-outside="[
      closeMobileSidebar,
      { ignore: ['#mobile-sidebar-launcher'] },
    ]"
    class="flex flex-col text-sm pb-px fixed top-0 ltr:left-0 rtl:right-0 h-full min-h-0 z-40 w-[216px] md:w-auto md:relative md:flex-shrink-0 md:ltr:translate-x-0 md:rtl:translate-x-0 bg-transparent"
    :class="[
      {
        'shadow-[0_18px_48px_rgba(15,23,42,0.18)] md:shadow-none':
          isMobileSidebarOpen,
        'ltr:-translate-x-full rtl:translate-x-full': !isMobileSidebarOpen,
        'transition-transform duration-200 ease-out md:transition-[width]':
          !isResizing,
      },
    ]"
    :style="isMobile ? undefined : { width: `${sidebarWidth}px` }"
  >
    <div class="flex flex-col flex-1 gap-4 min-h-0 min-w-0 pt-3 pb-3 px-2">
      <div
        class="flex flex-shrink-0 gap-2"
        :class="isEffectivelyCollapsed ? 'flex-col items-center' : ''"
      >
        <RouterLink
          v-if="!isEffectivelyCollapsed"
          :to="{ name: 'search' }"
          class="flex gap-2 items-center px-3 py-2 w-full h-10 rounded-pill outline outline-1 outline-n-border-glass bg-n-glass-soft backdrop-blur-glass-rail shadow-pill-soft transition-all duration-150 ease-out hover:bg-n-glass-strong"
        >
          <span
            class="flex-shrink-0 i-lucide-search size-4 text-n-text-body/60"
          />
          <span class="flex-grow text-start text-n-text-body/60">
            {{ t('COMBOBOX.SEARCH_PLACEHOLDER') }}
          </span>
          <span
            class="hidden tracking-wide pointer-events-none select-none text-n-text-body/60"
          >
            {{ searchShortcut }}
          </span>
        </RouterLink>
        <RouterLink
          v-else
          :to="{ name: 'search' }"
          class="flex items-center justify-center size-9 rounded-full outline outline-1 outline-n-border-glass bg-n-glass-soft backdrop-blur-glass-rail shadow-pill-soft transition-all duration-150 ease-out hover:bg-n-glass-strong"
          :title="t('COMBOBOX.SEARCH_PLACEHOLDER')"
        >
          <span class="i-lucide-search size-4 text-n-text-body" />
        </RouterLink>
        <ComposeConversation align-position="right" @close="onComposeClose">
          <template #trigger="{ toggle, isOpen }">
            <Button
              icon="i-lucide-pen-line"
              color="slate"
              size="sm"
              class="dark:hover:!bg-n-slate-9/30"
              :class="[
                isEffectivelyCollapsed
                  ? '!size-9 !rounded-full !outline-n-border-glass !text-n-text-body'
                  : '!h-10 !rounded-pill !outline-n-border-glass !text-n-text-body',
                { '!bg-n-glass-strong': isOpen },
              ]"
              @click="onComposeOpen(toggle)"
            />
          </template>
        </ComposeConversation>
      </div>
      <ul
        class="flex flex-1 flex-col gap-1.5 m-0 list-none min-h-0 min-w-0 overflow-y-auto no-scrollbar"
        :class="{ 'items-center': isEffectivelyCollapsed }"
      >
        <SidebarGroup
          v-for="item in menuItems"
          :key="item.name"
          v-bind="item"
        />
      </ul>
      <div
        class="flex flex-shrink-0 flex-col gap-2 items-center"
        :class="isEffectivelyCollapsed ? '' : ''"
      >
        <SidebarChangelogCard
          v-if="
            isOnChatwootCloud &&
            !isACustomBrandedInstance &&
            !isEffectivelyCollapsed
          "
        />
        <SidebarChangelogButton
          v-if="
            isOnChatwootCloud &&
            !isACustomBrandedInstance &&
            isEffectivelyCollapsed
          "
        />
        <button
          type="button"
          class="flex items-center justify-center cursor-pointer transition-all duration-150 bg-n-glass-soft text-n-text-body border border-n-border-glass-soft backdrop-blur-glass-rail backdrop-saturate-glass shadow-inset-hairline hover:bg-n-glass-strong hover:border-n-border-glass"
          :class="
            isEffectivelyCollapsed
              ? 'rounded-full size-9'
              : 'w-full h-9 rounded-pill gap-1.5 text-xs font-medium'
          "
          :title="
            isEffectivelyCollapsed ? t('SIDEBAR.EXPAND') : t('SIDEBAR.COLLAPSE')
          "
          @click="onToggleSidebar"
        >
          <span
            class="inline-flex size-3.5"
            :class="
              isEffectivelyCollapsed
                ? 'i-lucide-chevron-right rtl:i-lucide-chevron-left'
                : 'i-lucide-chevron-left rtl:i-lucide-chevron-right'
            "
          />
          <span v-if="!isEffectivelyCollapsed">
            {{ t('SIDEBAR.COLLAPSE') }}
          </span>
        </button>
      </div>
    </div>
    <!-- Resize Handle (desktop only) -->
    <div
      class="hidden md:block absolute top-0 h-full w-1 cursor-col-resize z-40 ltr:right-0 rtl:left-0 group"
      @mousedown="onResizeStart"
      @touchstart="onResizeStart"
      @dblclick="onResizeHandleDoubleClick"
    >
      <div
        class="absolute top-0 h-full w-px ltr:right-0 rtl:left-0 bg-transparent group-hover:bg-n-brand transition-colors"
        :class="{ 'bg-n-brand': isResizing }"
      />
    </div>
  </aside>
</template>
