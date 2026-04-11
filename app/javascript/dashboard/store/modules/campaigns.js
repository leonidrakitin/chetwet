import CampaignsAPI from '../../api/campaigns';

export const state = {
  campaigns: [],
  meta: {
    yclientsEnabled: false,
    yclientsIntegrations: [],
  },
  statistics: {},
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
    isFetchingStatistics: false,
  },
};

export const getters = {
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getMeta(_state) {
    return _state.meta;
  },
  getCampaigns(_state) {
    return [..._state.templates].sort((a, b) => b.id - a.id);
  },
  getStatistics(_state) {
    return _state.statistics;
  },
};

export const mutations = {
  SET_CAMPAIGNS(_state, campaigns) {
    _state.campaigns = campaigns;
  },
  SET_META(_state, meta) {
    _state.meta = meta || {
      yclientsEnabled: false,
      yclientsIntegrations: [],
    };
  },
  ADD_CAMPAIGN(_state, campaign) {
    _state.campaigns.unshift(campaign);
  },
  UPDATE_CAMPAIGN(_state, campaign) {
    const index = _state.campaigns.findIndex(c => c.id === campaign.id);
    if (index !== -1) {
      _state.campaigns.splice(index, 1, campaign);
    }
  },
  DELETE_CAMPAIGN(_state, id) {
    _state.campaigns = _state.campaigns.filter(c => c.id !== id);
  },
  SET_STATISTICS(_state, statistics) {
    _state.statistics = statistics || {};
  },
  SET_UI_FLAG(_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
};

export const actions = {
  async get({ commit }) {
    commit('SET_UI_FLAG', { isFetching: true });
    commit('SET_META', {
      yclientsEnabled: false,
      yclientsIntegrations: [],
    });
    try {
      const response = await CampaignsAPI.get();
      commit('SET_CAMPAIGNS', response.data.payload || []);
      commit('SET_META', {
        yclientsEnabled: response.data.meta?.yclients_enabled || false,
        yclientsIntegrations: response.data.meta?.yclients_integrations || [],
      });
    } catch (error) {
      throw new Error(error);
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },
  async create({ commit }, campaignData) {
    const response = await CampaignsAPI.create({
      campaign: campaignData,
    });
    commit('ADD_CAMPAIGN', response.data);
  },
  async update({ commit }, campaign) {
    const response = await CampaignsAPI.update(campaign.id, {
      campaign,
    });
    commit('UPDATE_CAMPAIGN', response.data);
  },
  async delete({ commit }, id) {
    await CampaignsAPI.delete(id);
    commit('DELETE_CAMPAIGN', id);
  },
  async sendNow({ commit }, id) {
    const response = await CampaignsAPI.sendNow(id);
    commit('UPDATE_CAMPAIGN', response.data);
  },
  async previewAudience(_, id) {
    const response = await CampaignsAPI.previewAudience(id);
    return response.data;
  },
  async fetchStatistics({ commit }) {
    commit('SET_UI_FLAG', { isFetchingStatistics: true });
    try {
      const response = await CampaignsAPI.statistics();
      commit('SET_STATISTICS', response.data.payload);
    } finally {
      commit('SET_UI_FLAG', { isFetchingStatistics: false });
    }
  },
};

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions,
};
