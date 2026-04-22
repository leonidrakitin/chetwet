import CaptainAssistantTemplateAPI from 'dashboard/api/captain/assistantTemplate';

const state = {
  records: [],
  uiFlags: {
    fetchingList: false,
    creatingAssistant: false,
  },
};

const getters = {
  getRecords: $state => $state.records,
  getUIFlags: $state => $state.uiFlags,
};

const actions = {
  async list({ commit }, { locale } = {}) {
    commit('SET_UI_FLAG', { fetchingList: true });
    try {
      const response = await CaptainAssistantTemplateAPI.list({ locale });
      commit('SET', response.data);
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { fetchingList: false });
    }
  },
  async createAssistant({ commit }, payload) {
    commit('SET_UI_FLAG', { creatingAssistant: true });
    try {
      const response =
        await CaptainAssistantTemplateAPI.createAssistant(payload);
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { creatingAssistant: false });
    }
  },
  async createAssistantWithAdaptedData({ commit }, payload) {
    commit('SET_UI_FLAG', { creatingAssistant: true });
    try {
      const response =
        await CaptainAssistantTemplateAPI.createAssistantWithAdaptedData(
          payload
        );
      return response.data;
    } finally {
      commit('SET_UI_FLAG', { creatingAssistant: false });
    }
  },
};

const mutations = {
  SET_UI_FLAG($state, data) {
    $state.uiFlags = { ...$state.uiFlags, ...data };
  },
  SET($state, data) {
    $state.records = data;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
