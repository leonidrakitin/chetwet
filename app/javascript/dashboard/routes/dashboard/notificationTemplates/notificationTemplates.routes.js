import { frontendURL } from 'dashboard/helper/URLHelper.js';
import Index from './Index.vue';
import TemplateEditorPage from './TemplateEditorPage.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/notification'),
      name: 'notification_templates_index',
      component: Index,
      meta: { permissions: ['administrator'] },
    },
    {
      path: frontendURL('accounts/:accountId/notification/new'),
      name: 'notification_templates_new',
      component: TemplateEditorPage,
      meta: { permissions: ['administrator'] },
    },
    {
      path: frontendURL('accounts/:accountId/notification/:templateId/edit'),
      name: 'notification_templates_edit',
      component: TemplateEditorPage,
      meta: { permissions: ['administrator'] },
    },
  ],
};
