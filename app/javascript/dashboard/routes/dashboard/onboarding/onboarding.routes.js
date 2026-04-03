import { frontendURL } from 'dashboard/helper/URLHelper';

const MigrationsWizard = () => import('./MigrationsWizard.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/onboarding/wizard'),
      name: 'onboarding_wizard',
      component: MigrationsWizard,
      meta: {
        permissions: ['administrator'],
      },
    },
  ],
};
