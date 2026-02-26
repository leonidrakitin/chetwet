const MOCK_TEMPLATES = [
  // ─── col 0: источники (ничто не ссылается на них) ───────────────────────
  {
    id: 41403,
    name: 'На изменение записи',
    description: '',
    type: 'event',
    triggerEvent: 'UPDATED',
    messages: [
      {
        text: 'Здравствуйте, {client_name}! Ваша запись изменена: {service_name} {date} в {time}.',
        attachments: [],
        buttons: [
          {
            id: 'btn-u1',
            label: 'Подтвердить',
            type: 'template',
            templateId: 730569,
          },
          {
            id: 'btn-u2',
            label: 'Отменить',
            type: 'template',
            templateId: 982055,
          },
        ],
      },
    ],
    enabled: true,
    order: 0,
  },
  {
    id: 824540,
    name: 'На оплату записи',
    description: '',
    type: 'event',
    triggerEvent: 'PAID',
    messages: [
      {
        text: 'Здравствуйте, {client_name}! Оплата {price} принята. Ждём вас {date} в {time}.',
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
            id: 'btn-p1',
            label: 'Посмотреть чек',
            type: 'url',
            url: 'https://example.com/receipt',
          },
          {
            id: 'btn-p2',
            label: 'Напомнить за день',
            type: 'template',
            templateId: 111001,
          },
        ],
      },
    ],
    enabled: true,
    order: 1,
  },

  // ─── col 1: первый шаг цепочки ──────────────────────────────────────────
  {
    id: 730569,
    name: 'На создание записи',
    description: '',
    type: 'event',
    triggerEvent: 'CREATED',
    messages: [
      {
        text: 'Здравствуйте, {client_name}! Вы записаны на {service_name} {date} в {time}. Ждём в {branch_name}.',
        attachments: [],
        buttons: [
          {
            id: 'btn-c1',
            label: 'Напомнить за день',
            type: 'template',
            templateId: 111001,
          },
        ],
      },
    ],
    enabled: true,
    order: 2,
  },
  {
    id: 982055,
    name: 'На отмену записи',
    description: '',
    type: 'event',
    triggerEvent: 'DELETED',
    messages: [
      {
        text: 'Здравствуйте, {client_name}! Ваша запись на {service_name} {date} отменена. Будем рады видеть вас снова!',
        attachments: [],
        buttons: [
          {
            id: 'btn-d1',
            label: 'Записаться снова',
            type: 'template',
            templateId: 111004,
          },
        ],
      },
    ],
    enabled: true,
    order: 3,
  },

  // ─── col 2: напоминание за день ─────────────────────────────────────────
  {
    id: 111001,
    name: 'Напоминание за день',
    description: '',
    type: 'time',
    triggerEvent: null,
    messages: [
      {
        text: 'Здравствуйте, {client_name}! Напоминаем: завтра {date} в {time} у вас {service_name} в {branch_name}.',
        attachments: [],
        buttons: [
          {
            id: 'btn-r1',
            label: 'Подтверждаю ✓',
            type: 'template',
            templateId: 111002,
          },
          {
            id: 'btn-r2',
            label: 'Отменить запись',
            type: 'template',
            templateId: 982055,
          },
        ],
      },
    ],
    enabled: true,
    order: 4,
  },

  // ─── col 3: напоминание за 2 часа ───────────────────────────────────────
  {
    id: 111002,
    name: 'Напоминание за 2 часа',
    description: '',
    type: 'time',
    triggerEvent: null,
    messages: [
      {
        text: 'Здравствуйте, {client_name}! Через 2 часа вас ждёт {service_name}. Мастер {master_name} готов принять вас.',
        attachments: [],
        buttons: [
          {
            id: 'btn-h1',
            label: 'Уже еду!',
            type: 'template',
            templateId: 951339,
          },
          {
            id: 'btn-h2',
            label: 'Нужно отменить',
            type: 'template',
            templateId: 982055,
          },
        ],
      },
    ],
    enabled: true,
    order: 5,
  },

  // ─── col 4: клиент в салоне ─────────────────────────────────────────────
  {
    id: 951339,
    name: 'Клиент в салоне',
    description: '',
    type: 'event',
    triggerEvent: 'ARRIVED',
    messages: [
      {
        text: 'Здравствуйте, {client_name}! Рады вас видеть в {branch_name}. Мастер {master_name} уже ждёт вас.',
        attachments: [],
        buttons: [
          {
            id: 'btn-a1',
            label: 'После визита',
            type: 'template',
            templateId: 111003,
          },
        ],
      },
    ],
    enabled: true,
    order: 6,
  },

  // ─── col 5: после визита ────────────────────────────────────────────────
  {
    id: 111003,
    name: 'После визита',
    description: '',
    type: 'event',
    triggerEvent: 'COMPLETED',
    messages: [
      {
        text: 'Спасибо, {client_name}! Надеемся, вам понравилось. Будем рады видеть вас снова в {branch_name}!',
        attachments: [],
        buttons: [
          {
            id: 'btn-v1',
            label: 'Оставить отзыв',
            type: 'url',
            url: 'https://example.com/review',
          },
          {
            id: 'btn-v2',
            label: 'Записаться снова',
            type: 'template',
            templateId: 111004,
          },
        ],
      },
    ],
    enabled: true,
    order: 7,
  },

  // ─── col 6: повторная запись (конечный узел) ────────────────────────────
  {
    id: 111004,
    name: 'Приглашение на повтор',
    description: '',
    type: 'lost_clients',
    triggerEvent: null,
    messages: [
      {
        text: 'Здравствуйте, {client_name}! Давно не видели вас. Запишитесь на {service_name} — мастер {master_name} ждёт!',
        attachments: [],
        buttons: [],
      },
    ],
    enabled: true,
    order: 8,
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
      messages: templateData.messages ?? [],
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
