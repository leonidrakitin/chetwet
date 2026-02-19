const MOCK_TEMPLATES = [
  {
    id: 730569,
    name: 'На создание записи',
    description: '',
    type: 'event',
    triggerEvent: 'CREATED',
    messageText:
      'Здравствуйте, {client_name}! Вы записаны на {service_name} {date} в {time}. Ждём вас в {branch_name}.',
    enabled: true,
  },
  {
    id: 41403,
    name: 'На изменение записи',
    description: '',
    type: 'event',
    triggerEvent: 'UPDATED',
    messageText:
      'Здравствуйте, {client_name}! Ваша запись изменена: {service_name} {date} в {time}.',
    enabled: true,
  },
  {
    id: 982055,
    name: 'На удаление записи',
    description: '',
    type: 'event',
    triggerEvent: 'DELETED',
    messageText:
      'Здравствуйте, {client_name}! Ваша запись на {service_name} {date} была отменена.',
    enabled: false,
  },
  {
    id: 824540,
    name: 'На оплату записи',
    description: '',
    type: 'event',
    triggerEvent: 'PAID',
    messageText:
      'Здравствуйте, {client_name}! Оплата на сумму {price} успешно принята. Ждём вас {date} в {time}.',
    enabled: true,
  },
  {
    id: 951339,
    name: 'Клиент в салоне',
    description: '',
    type: 'event',
    triggerEvent: 'ARRIVED',
    messageText:
      'Здравствуйте, {client_name}! Рады приветствовать вас в {branch_name}. Ваш мастер {master_name} ждёт вас.',
    enabled: true,
  },
];

let nextId = 1000000;

export const state = {
  templates: [...MOCK_TEMPLATES],
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
  getTemplates(_state) {
    return _state.templates;
  },
  getTemplatesByType: _state => type => {
    return _state.templates.filter(t => t.type === type);
  },
};

export const mutations = {
  SET_TEMPLATES(_state, templates) {
    _state.templates = templates;
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
};

export const actions = {
  get({ commit }) {
    commit('SET_TEMPLATES', [...MOCK_TEMPLATES]);
  },
  create({ commit }, templateData) {
    nextId += 1;
    const template = { ...templateData, id: nextId };
    commit('ADD_TEMPLATE', template);
  },
  update({ commit }, template) {
    commit('UPDATE_TEMPLATE', template);
  },
  delete({ commit }, id) {
    commit('DELETE_TEMPLATE', id);
  },
  toggle({ commit, state: _state }, id) {
    const template = _state.templates.find(t => t.id === id);
    if (template) {
      commit('UPDATE_TEMPLATE', { ...template, enabled: !template.enabled });
    }
  },
  clone({ commit, state: _state }, id) {
    const template = _state.templates.find(t => t.id === id);
    if (template) {
      nextId += 1;
      commit('ADD_TEMPLATE', {
        ...template,
        id: nextId,
        name: `${template.name} (copy)`,
      });
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
