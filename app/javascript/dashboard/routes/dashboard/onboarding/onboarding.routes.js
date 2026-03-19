import { frontendURL } from 'dashboard/helper/URLHelper';

const OnboardingWizard = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/onboarding/wizard'),
      name: 'onboarding_wizard',
      component: OnboardingWizard,
      meta: {
        permissions: ['administrator'],
      },
    },
  ],
};
