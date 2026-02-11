import { frontendURL } from '../../../helper/URLHelper';
import SegmentsDashboard from './pages/SegmentsDashboard.vue';
import SegmentShow from './pages/SegmentShow.vue';
import { FEATURE_FLAGS } from '../../../featureFlags';

const commonMeta = {
  featureFlag: FEATURE_FLAGS.CRM,
  permissions: ['administrator', 'agent', 'contact_manage'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/segments'),
    component: {
      template: '<router-view />',
    },
    meta: commonMeta,
    children: [
      {
        path: '',
        name: 'segments_dashboard',
        component: SegmentsDashboard,
        meta: commonMeta,
      },
      {
        path: ':segmentId',
        name: 'segment_show',
        component: SegmentShow,
        meta: commonMeta,
      },
    ],
  },
];
