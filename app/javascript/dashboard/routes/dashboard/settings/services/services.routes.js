import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import ServicesIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/services'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'services_wrapper',
          meta: {
            permissions: ['administrator', 'agent'],
          },
          redirect: to => {
            return { name: 'services_list', params: to.params };
          },
        },
        {
          path: 'list',
          name: 'services_list',
          meta: {
            permissions: ['administrator', 'agent'],
          },
          component: ServicesIndex,
        },
      ],
    },
  ],
};
