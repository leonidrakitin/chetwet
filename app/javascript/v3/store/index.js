import { createStore } from 'vuex';
import globalConfig from 'shared/store/globalConfig';
import auth from 'dashboard/store/modules/auth';

export default createStore({
  modules: {
    globalConfig,
    auth,
  },
});
