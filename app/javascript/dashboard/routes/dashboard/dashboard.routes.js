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
import onboardingRoutes from './onboarding/onboarding.routes';
import suggestionsRoutes from './suggestions/suggestions.routes';
import AppContainer from './Dashboard.vue';
import Suspended from './suspended/Index.vue';
import NoAccounts from './noAccounts/Index.vue';
import YclientsConnect from './settings/integrations/YclientsConnect.vue';

export default {
  routes: [
    {
      path: frontendURL('yclients/connect'),
      name: 'yclients_connect',
      component: YclientsConnect,
      meta: {},
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
        ...onboardingRoutes.routes,
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
