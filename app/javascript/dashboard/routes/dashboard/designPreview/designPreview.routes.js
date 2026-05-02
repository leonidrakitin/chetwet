import { frontendURL } from '../../../helper/URLHelper';
import DesignPreview from './DesignPreview.vue';

export default [
  {
    path: frontendURL('design-preview'),
    name: 'design_preview',
    component: DesignPreview,
    meta: {},
  },
];
