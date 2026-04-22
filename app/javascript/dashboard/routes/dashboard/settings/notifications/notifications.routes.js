import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import NotificationsSettingsPage from './NotificationsSettingsPage.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/notifications'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'notifications_settings',
          meta: {
            permissions: ['administrator'],
          },
          component: NotificationsSettingsPage,
        },
      ],
    },
  ],
};
