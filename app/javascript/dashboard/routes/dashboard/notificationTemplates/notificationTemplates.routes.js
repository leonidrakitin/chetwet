import { frontendURL } from 'dashboard/helper/URLHelper.js';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/notification-templates'),
      name: 'notification_templates_index',
      component: Index,
      meta: { permissions: ['administrator'] },
    },
  ],
};
