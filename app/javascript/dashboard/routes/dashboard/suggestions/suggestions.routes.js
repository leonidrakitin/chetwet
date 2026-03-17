import { frontendURL } from 'dashboard/helper/URLHelper.js';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/suggestions'),
      name: 'suggestions_index',
      component: Index,
      meta: { permissions: ['administrator', 'agent', 'custom_role'] },
    },
  ],
};
