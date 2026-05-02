import settings from './settings/settings.routes';
import conversation from './conversation/conversation.routes';
import { routes as searchRoutes } from '../../modules/search/search.routes';
import { routes as contactRoutes } from './contacts/routes';
import { routes as notificationRoutes } from './notifications/routes';
import { routes as inboxRoutes } from './inbox/routes';
import { frontendURL } from '../../helper/URLHelper';
import helpcenterRoutes from './helpcenter/helpcenter.routes';
import { routes as captainRoutes } from './captain/captain.routes';
import notificationTemplatesRoutes from './notificationTemplates/notificationTemplates.routes';
import campaignsRoutes from './campaigns/campaigns.routes';
import suggestionsRoutes from './suggestions/suggestions.routes';
import AppContainer from './Dashboard.vue';
import OnboardingWizard from './onboarding/Index.vue';
import Suspended from './suspended/Index.vue';
import NoAccounts from './noAccounts/Index.vue';
import YclientsConnect from './settings/integrations/YclientsConnect.vue';
import designPreviewRoutes from './designPreview/designPreview.routes';

export default {
  routes: [
    {
      path: frontendURL('yclients/connect'),
      name: 'yclients_connect',
      component: YclientsConnect,
      meta: {},
    },
    ...designPreviewRoutes,
    {
      path: frontendURL('onboarding/wizard'),
      name: 'onboarding_wizard',
      component: OnboardingWizard,
      meta: {
        permissions: ['administrator'],
      },
    },
    {
      path: frontendURL('accounts/:accountId/onboarding/wizard'),
      redirect: to => ({
        path: frontendURL('onboarding/wizard'),
        query: to.query,
      }),
    },
    {
      path: frontendURL('accounts/:accountId'),
      component: AppContainer,
      children: [
        ...captainRoutes,
        ...inboxRoutes,
        ...conversation.routes,
        ...settings.routes,
        ...contactRoutes,
        ...searchRoutes,
        ...notificationRoutes,
        ...helpcenterRoutes.routes,
        ...notificationTemplatesRoutes.routes,
        ...campaignsRoutes.routes,
        ...suggestionsRoutes.routes,
      ],
    },
    {
      path: frontendURL('accounts/:accountId/suspended'),
      name: 'account_suspended',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: Suspended,
    },
    {
      path: frontendURL('no-accounts'),
      name: 'no_accounts',
      component: NoAccounts,
    },
  ],
};
