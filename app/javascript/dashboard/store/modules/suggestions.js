import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import SuggestionsAPI from '../../api/suggestions';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
  },
};

export const getters = {
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getSuggestions(_state) {
    return _state.records;
  },
};

export const actions = {
  get: async function getSuggestions({ commit }, params = {}) {
    commit(types.SET_SUGGESTION_UI_FLAG, { isFetching: true });
    try {
      const response = await SuggestionsAPI.get(params ?? {});
      commit(types.SET_SUGGESTIONS, response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_SUGGESTION_UI_FLAG, { isFetching: false });
    }
  },
  create: async function createSuggestion({ commit }, data) {
    commit(types.SET_SUGGESTION_UI_FLAG, { isCreating: true });
    try {
      const response = await SuggestionsAPI.create(data);
      commit(types.ADD_SUGGESTION, response.data);
    } finally {
      commit(types.SET_SUGGESTION_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...updateObj }) => {
    const response = await SuggestionsAPI.update(id, updateObj);
    commit(types.EDIT_SUGGESTION, response.data);
  },
  delete: async ({ commit }, id) => {
    await SuggestionsAPI.delete(id);
    commit(types.DELETE_SUGGESTION, id);
  },
  vote: async ({ commit }, { id, voteType }) => {
    try {
      const response = await SuggestionsAPI.vote(id, voteType);
      commit(types.EDIT_SUGGESTION, response.data);
    } catch (error) {
      throw new Error(error);
    }
  },
  addTag: async ({ commit }, { id, tag }) => {
    try {
      const response = await SuggestionsAPI.addTag(id, tag);
      commit(types.EDIT_SUGGESTION, response.data);
    } catch (error) {
      throw new Error(error);
    }
  },
  removeTag: async ({ commit }, { id, tag }) => {
    try {
      const response = await SuggestionsAPI.removeTag(id, tag);
      commit(types.EDIT_SUGGESTION, response.data);
    } catch (error) {
      throw new Error(error);
    }
  },
};

export const mutations = {
  [types.SET_SUGGESTION_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },
  [types.ADD_SUGGESTION]: MutationHelpers.create,
  [types.SET_SUGGESTIONS]: MutationHelpers.set,
  [types.EDIT_SUGGESTION]: MutationHelpers.updateAttributes,
  [types.DELETE_SUGGESTION]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
