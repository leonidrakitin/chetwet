import { createStore } from 'vuex';
import globalConfig from 'shared/store/globalConfig';
import auth from 'dashboard/store/modules/auth';
import captainAssistants from 'dashboard/store/captain/assistant';

export default createStore({
  modules: {
    globalConfig,
    auth,
    captainAssistants,
  },
});
