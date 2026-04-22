import { frontendURL } from 'dashboard/helper/URLHelper.js';
import Index from './Index.vue';
import TemplateEditorPage from './TemplateEditorPage.vue';

const meta = { permissions: ['administrator'] };

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/notification'),
      name: 'notification_templates_index',
      component: Index,
      meta,
    },
    {
      path: frontendURL('accounts/:accountId/notification/marketing'),
      name: 'notification_templates_marketing',
      component: Index,
      meta,
    },
    {
      path: frontendURL('accounts/:accountId/notification/service'),
      name: 'notification_templates_service',
      component: Index,
      meta,
    },
    {
      path: frontendURL('accounts/:accountId/notification/statistics'),
      name: 'notification_templates_statistics',
      component: Index,
      meta,
    },
    {
      path: frontendURL('accounts/:accountId/notification/delivery'),
      name: 'notification_templates_delivery',
      component: Index,
      meta,
    },
    {
      path: frontendURL('accounts/:accountId/notification/new'),
      name: 'notification_templates_new',
      component: TemplateEditorPage,
      meta,
    },
    {
      path: frontendURL('accounts/:accountId/notification/:templateId/edit'),
      name: 'notification_templates_edit',
      component: TemplateEditorPage,
      meta,
    },
  ],
};
