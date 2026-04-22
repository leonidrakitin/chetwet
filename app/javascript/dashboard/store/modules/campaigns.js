import CampaignsAPI from '../../api/campaigns';

export const state = {
  campaigns: [],
  meta: {
    yclientsEnabled: false,
    yclientsIntegrations: [],
  },
  statistics: {},
  statisticsSummary: {},
  timeSeries: {},
  scheduledCampaigns: [],
  campaignStatistics: {},
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
    isFetchingStatistics: false,
    isFetchingTimeSeries: false,
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
    return [..._state.campaigns].sort((a, b) => b.id - a.id);
  },
  getStatistics(_state) {
    return _state.statistics;
  },
  getStatisticsSummary(_state) {
    return _state.statisticsSummary;
  },
  getTimeSeries(_state) {
    return _state.timeSeries;
  },
  getScheduledCampaigns(_state) {
    return _state.scheduledCampaigns;
  },
  getCampaignStatistics(_state) {
    return _state.campaignStatistics;
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
  SET_STATISTICS_SUMMARY(_state, summary) {
    _state.statisticsSummary = summary || {};
  },
  SET_TIME_SERIES(_state, timeSeries) {
    _state.timeSeries = timeSeries || {};
  },
  SET_SCHEDULED_CAMPAIGNS(_state, scheduled) {
    _state.scheduledCampaigns = scheduled || [];
  },
  SET_CAMPAIGN_STATISTICS(_state, campaignId, statistics) {
    _state.campaignStatistics = {
      ..._state.campaignStatistics,
      [campaignId]: statistics,
    };
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
      const payload = response.data?.payload ?? response.data ?? [];
      const campaigns = Array.isArray(payload) ? payload : [];
      const normalizedCampaigns = campaigns.map(campaign => ({
        ...campaign,
        name: campaign.name ?? campaign.title ?? '',
        messageText:
          campaign.messageText ??
          campaign.message ??
          campaign.messages?.[0]?.text ??
          '',
        inbox_id: campaign.inbox_id ?? campaign.inbox?.id ?? null,
      }));
      commit('SET_CAMPAIGNS', normalizedCampaigns);
      commit('SET_META', {
        yclientsEnabled: response.data.meta?.yclients_enabled || false,
        yclientsIntegrations: response.data.meta?.yclients_integrations || [],
      });
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
  async fetchStatistics({ commit }, period = '30d') {
    commit('SET_UI_FLAG', { isFetchingStatistics: true });
    try {
      const response = await CampaignsAPI.statistics(period);
      const payload = response.data.payload || {};
      commit('SET_STATISTICS', payload.by_campaign || {});
      commit('SET_STATISTICS_SUMMARY', payload.summary || {});
      commit('SET_TIME_SERIES', payload.time_series || {});
      commit('SET_SCHEDULED_CAMPAIGNS', payload.scheduled || []);
    } finally {
      commit('SET_UI_FLAG', { isFetchingStatistics: false });
    }
  },
  async fetchCampaignStatistics({ commit }, { id, period = '30d' }) {
    commit('SET_UI_FLAG', { isFetchingStatistics: true });
    try {
      const response = await CampaignsAPI.campaignStatistics(id, period);
      commit('SET_CAMPAIGN_STATISTICS', id, response.data.payload || {});
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
