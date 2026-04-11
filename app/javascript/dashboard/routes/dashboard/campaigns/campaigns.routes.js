import { frontendURL } from 'dashboard/helper/URLHelper.js';
import Index from './Index.vue';
import CampaignEditor from './CampaignEditor.vue';

const meta = { permissions: ['administrator'] };

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/campaigns'),
      name: 'campaigns_index',
      component: Index,
      meta,
    },
    {
      path: frontendURL('accounts/:accountId/campaigns/statistics'),
      name: 'campaigns_statistics',
      component: Index,
      meta,
    },
    {
      path: frontendURL('accounts/:accountId/campaigns/new'),
      name: 'campaigns_new',
      component: CampaignEditor,
      meta,
    },
    {
      path: frontendURL('accounts/:accountId/campaigns/:campaignId/edit'),
      name: 'campaigns_edit',
      component: CampaignEditor,
      meta,
    },
  ],
};
