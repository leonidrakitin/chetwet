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
    order: 0,
    attachments: [],
    buttons: [],
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
    order: 1,
    attachments: [],
    buttons: [
      {
        id: 'btn-1',
        label: 'Подтвердить',
        type: 'template',
        templateId: 730569,
      },
    ],
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
    order: 2,
    attachments: [],
    buttons: [],
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
    order: 3,
    attachments: [
      {
        id: 'att-1',
        type: 'link',
        name: 'Чек об оплате',
        url: 'https://example.com/receipt',
      },
    ],
    buttons: [
      {
        id: 'btn-2',
        label: 'Посмотреть чек',
        type: 'url',
        url: 'https://example.com/receipt',
      },
    ],
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
    order: 4,
    attachments: [],
    buttons: [],
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
};

export const actions = {
  get({ commit }) {
    commit(
      'SET_TEMPLATES',
      MOCK_TEMPLATES.map((t, i) => ({ ...t, order: t.order ?? i }))
    );
  },
  create({ commit, state: _state }, templateData) {
    nextId += 1;
    const template = {
      ...templateData,
      id: nextId,
      order: _state.templates.length,
      attachments: templateData.attachments ?? [],
      buttons: templateData.buttons ?? [],
    };
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
        order: _state.templates.length,
      });
    }
  },
  reorder({ commit }, templates) {
    commit('REORDER_TEMPLATES', templates);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions,
};
