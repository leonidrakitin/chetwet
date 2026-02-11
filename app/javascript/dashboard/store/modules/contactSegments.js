import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import ContactSegmentsAPI from '../../api/contactSegments';

export const state = {
  records: [],
  changeLogs: {},
  statistics: {},
  dashboardStats: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
    isPreviewing: false,
    isFetchingDashboard: false,
  },
};

export const getters = {
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getSegments(_state) {
    return _state.records;
  },
  getSegmentById: _state => id => {
    return _state.records.find(record => record.id === Number(id));
  },
  getChangeLogsBySegmentId: _state => id => {
    return _state.changeLogs[id] || { data: [], meta: {} };
  },
  getStatisticsBySegmentId: _state => id => {
    return _state.statistics[id] || {};
  },
  getDashboardStats(_state) {
    return _state.dashboardStats;
  },
};

export const actions = {
  get: async function getSegments({ commit }) {
    commit(types.SET_CONTACT_SEGMENT_UI_FLAG, { isFetching: true });
    try {
      const response = await ContactSegmentsAPI.get();
      commit(types.SET_CONTACT_SEGMENTS, response.data.payload);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_CONTACT_SEGMENT_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createSegment({ commit }, data) {
    commit(types.SET_CONTACT_SEGMENT_UI_FLAG, { isCreating: true });
    try {
      const response = await ContactSegmentsAPI.create(data);
      commit(types.ADD_CONTACT_SEGMENT, response.data);
      return response.data;
    } catch (error) {
      const errorMessage = error?.response?.data?.message;
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_CONTACT_SEGMENT_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updateSegment({ commit }, { id, ...data }) {
    commit(types.SET_CONTACT_SEGMENT_UI_FLAG, { isUpdating: true });
    try {
      const response = await ContactSegmentsAPI.update(id, data);
      commit(types.EDIT_CONTACT_SEGMENT, response.data);
      return response.data;
    } catch (error) {
      const errorMessage = error?.response?.data?.message;
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_CONTACT_SEGMENT_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteSegment({ commit }, id) {
    commit(types.SET_CONTACT_SEGMENT_UI_FLAG, { isDeleting: true });
    try {
      await ContactSegmentsAPI.delete(id);
      commit(types.DELETE_CONTACT_SEGMENT, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_CONTACT_SEGMENT_UI_FLAG, { isDeleting: false });
    }
  },

  preview: async function previewSegment(_, id) {
    const response = await ContactSegmentsAPI.preview(id);
    return response.data;
  },

  previewQuery: async function previewQuery(_, query) {
    const response = await ContactSegmentsAPI.previewQuery(query);
    return response.data;
  },

  getStatistics: async function getStatistics({ commit }, segmentId) {
    try {
      const response = await ContactSegmentsAPI.getStatistics(segmentId);
      commit(types.SET_CONTACT_SEGMENT_STATISTICS, {
        segmentId,
        data: response.data,
      });
      return response.data;
    } catch (error) {
      // Ignore error
    }
    return {};
  },

  getDashboardStats: async function getDashboardStats({ commit }) {
    commit(types.SET_CONTACT_SEGMENT_UI_FLAG, { isFetchingDashboard: true });
    try {
      const response = await ContactSegmentsAPI.getDashboard();
      commit(types.SET_CONTACT_SEGMENT_DASHBOARD_STATS, response.data.payload);
      return response.data.payload;
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_CONTACT_SEGMENT_UI_FLAG, { isFetchingDashboard: false });
    }
    return [];
  },

  getChangeLogs: async function getChangeLogs({ commit }, { segmentId, page = 1 }) {
    try {
      const response = await ContactSegmentsAPI.getChangeLogs(segmentId, page);
      commit(types.SET_CONTACT_SEGMENT_CHANGE_LOGS, {
        segmentId,
        data: response.data,
      });
      return response.data;
    } catch (error) {
      // Ignore error
    }
    return {};
  },
};

export const mutations = {
  [types.SET_CONTACT_SEGMENT_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_CONTACT_SEGMENTS](_state, data) {
    _state.records = data;
  },

  [types.ADD_CONTACT_SEGMENT]: MutationHelpers.create,
  [types.EDIT_CONTACT_SEGMENT]: MutationHelpers.update,
  [types.DELETE_CONTACT_SEGMENT]: MutationHelpers.destroy,

  [types.SET_CONTACT_SEGMENT_CHANGE_LOGS](_state, { segmentId, data }) {
    _state.changeLogs = {
      ..._state.changeLogs,
      [segmentId]: data,
    };
  },

  [types.SET_CONTACT_SEGMENT_STATISTICS](_state, { segmentId, data }) {
    _state.statistics = {
      ..._state.statistics,
      [segmentId]: data,
    };
  },

  [types.SET_CONTACT_SEGMENT_DASHBOARD_STATS](_state, data) {
    _state.dashboardStats = data;
  },
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
