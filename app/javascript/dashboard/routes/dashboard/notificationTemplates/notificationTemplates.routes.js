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
      path: frontendURL('accounts/:accountId/notification/event'),
      name: 'notification_templates_event',
      component: Index,
      meta,
    },
    {
      path: frontendURL('accounts/:accountId/notification/time'),
      name: 'notification_templates_time',
      component: Index,
      meta,
    },
    {
      path: frontendURL('accounts/:accountId/notification/interval'),
      name: 'notification_templates_interval',
      component: Index,
      meta,
    },
    {
      path: frontendURL('accounts/:accountId/notification/one-time'),
      name: 'notification_templates_one_time',
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
      path: frontendURL('accounts/:accountId/notification/statistics'),
      name: 'notification_templates_statistics',
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
