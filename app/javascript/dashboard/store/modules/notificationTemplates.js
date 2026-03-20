import NotificationTemplatesAPI from '../../api/notificationTemplates';

export const state = {
  templates: [],
  meta: {
    yclientsEnabled: false,
    yclientsIntegrations: [],
  },
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
  getMeta(_state) {
    return _state.meta;
  },
  getTemplates(_state) {
    return [..._state.templates].sort(
      (a, b) => (a.order ?? 0) - (b.order ?? 0)
    );
  },
  getTemplatesByType: _state => type => {
    return _state.templates.filter(t => t.type === type);
  },
};

export const mutations = {
  SET_TEMPLATES(_state, templates) {
    _state.templates = templates;
  },
  SET_META(_state, meta) {
    _state.meta = meta || {
      yclientsEnabled: false,
      yclientsIntegrations: [],
    };
  },
  ADD_TEMPLATE(_state, template) {
    _state.templates.push(template);
  },
  UPDATE_TEMPLATE(_state, template) {
    const index = _state.templates.findIndex(t => t.id === template.id);
    if (index !== -1) {
      _state.templates.splice(index, 1, template);
    }
  },
  DELETE_TEMPLATE(_state, id) {
    _state.templates = _state.templates.filter(t => t.id !== id);
  },
  REORDER_TEMPLATES(_state, templates) {
    _state.templates = templates.map((t, index) => ({ ...t, order: index }));
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
      const response = await NotificationTemplatesAPI.get();
      commit('SET_TEMPLATES', response.data.payload || []);
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
  async create({ commit, state: _state }, templateData) {
    const response = await NotificationTemplatesAPI.create({
      notification_template: {
        ...templateData,
        position: templateData.order ?? _state.templates.length,
      },
    });
    commit('ADD_TEMPLATE', response.data);
  },
  async update({ commit }, template) {
    const response = await NotificationTemplatesAPI.update(template.id, {
      notification_template: {
        ...template,
        position: template.order,
      },
    });
    commit('UPDATE_TEMPLATE', response.data);
  },
  async delete({ commit }, id) {
    await NotificationTemplatesAPI.delete(id);
    commit('DELETE_TEMPLATE', id);
  },
  async clone({ commit }, id) {
    const response = await NotificationTemplatesAPI.clone(id);
    commit('ADD_TEMPLATE', response.data);
  },
  async reorder({ commit }, templates) {
    const reorderedTemplates = templates.map((template, index) => ({
      id: template.id,
      position: index,
    }));
    const response = await NotificationTemplatesAPI.reorder(reorderedTemplates);
    commit('SET_TEMPLATES', response.data.payload || []);
    commit('SET_META', {
      yclientsEnabled: response.data.meta?.yclients_enabled || false,
      yclientsIntegrations: response.data.meta?.yclients_integrations || [],
    });
  },
};

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions,
};
