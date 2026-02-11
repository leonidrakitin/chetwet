import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import SegmentNotificationTypesAPI from '../../api/segmentNotificationTypes';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getNotificationTypes(_state) {
    return _state.records;
  },
  getNotificationTypeById: _state => id => {
    return _state.records.find(record => record.id === Number(id));
  },
};

export const actions = {
  get: async function getNotificationTypes({ commit }) {
    commit(types.SET_SEGMENT_NOTIFICATION_TYPE_UI_FLAG, { isFetching: true });
    try {
      const response = await SegmentNotificationTypesAPI.get();
      commit(types.SET_SEGMENT_NOTIFICATION_TYPES, response.data.payload);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_SEGMENT_NOTIFICATION_TYPE_UI_FLAG, {
        isFetching: false,
      });
    }
  },

  create: async function createNotificationType({ commit }, data) {
    commit(types.SET_SEGMENT_NOTIFICATION_TYPE_UI_FLAG, { isCreating: true });
    try {
      const response = await SegmentNotificationTypesAPI.create(data);
      commit(types.ADD_SEGMENT_NOTIFICATION_TYPE, response.data);
      return response.data;
    } catch (error) {
      const errorMessage = error?.response?.data?.message;
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_SEGMENT_NOTIFICATION_TYPE_UI_FLAG, {
        isCreating: false,
      });
    }
  },

  update: async function updateNotificationType({ commit }, { id, ...data }) {
    commit(types.SET_SEGMENT_NOTIFICATION_TYPE_UI_FLAG, { isUpdating: true });
    try {
      const response = await SegmentNotificationTypesAPI.update(id, data);
      commit(types.EDIT_SEGMENT_NOTIFICATION_TYPE, response.data);
      return response.data;
    } catch (error) {
      const errorMessage = error?.response?.data?.message;
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_SEGMENT_NOTIFICATION_TYPE_UI_FLAG, {
        isUpdating: false,
      });
    }
  },

  delete: async function deleteNotificationType({ commit }, id) {
    commit(types.SET_SEGMENT_NOTIFICATION_TYPE_UI_FLAG, { isDeleting: true });
    try {
      await SegmentNotificationTypesAPI.delete(id);
      commit(types.DELETE_SEGMENT_NOTIFICATION_TYPE, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SEGMENT_NOTIFICATION_TYPE_UI_FLAG, {
        isDeleting: false,
      });
    }
  },
};

export const mutations = {
  [types.SET_SEGMENT_NOTIFICATION_TYPE_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_SEGMENT_NOTIFICATION_TYPES](_state, data) {
    _state.records = data;
  },

  [types.ADD_SEGMENT_NOTIFICATION_TYPE]: MutationHelpers.create,
  [types.EDIT_SEGMENT_NOTIFICATION_TYPE]: MutationHelpers.update,
  [types.DELETE_SEGMENT_NOTIFICATION_TYPE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
