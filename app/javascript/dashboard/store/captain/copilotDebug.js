import CopilotDebugAPI from 'dashboard/api/captain/copilotDebug';
import { createStore } from '../storeFactory';

export default createStore({
  name: 'CopilotDebug',
  API: CopilotDebugAPI,
  getters: {
    getDebugData: state => threadId => {
      return state.records[threadId] || null;
    },
  },
  actions: mutationTypes => ({
    setDebugData({ commit }, { threadId, data }) {
      commit(mutationTypes.SET, { [threadId]: data });
    },
    clearDebugData({ commit }, threadId) {
      commit(mutationTypes.REMOVE, threadId);
    },
  }),
});
