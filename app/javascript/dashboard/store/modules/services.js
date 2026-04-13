import types from '../mutation-types';
import ProvidersAPI from '../../api/providers';
import ServicesAPI from '../../api/servicesApi';
import BookingsAPI from '../../api/bookings';
import ScheduleAPI from '../../api/schedule';
import ProviderScheduleAPI from '../../api/providerSchedule';

const createSetMutation = key => (state, data) => {
  state[key] = data;
};

const createCreateMutation = key => (state, data) => {
  state[key].push(data);
};

const createUpdateMutation = key => (state, data) => {
  state[key].forEach((element, index) => {
    if (element.id === data.id) {
      state[key][index] = data;
    }
  });
};

const createDestroyMutation = key => (state, id) => {
  state[key] = state[key].filter(record => record.id !== id);
};

export const state = {
  providers: [],
  services: [],
  bookings: [],
  schedule: null,
  calendarBookings: [],
  calendarProviders: [],
  uiFlags: {
    isFetchingProviders: false,
    isFetchingServices: false,
    isFetchingBookings: false,
    isCreatingProvider: false,
    isCreatingService: false,
    isCreatingBooking: false,
    isUpdatingProvider: false,
    isUpdatingService: false,
    isDeletingProvider: false,
    isDeletingService: false,
    isFetchingCalendar: false,
    isFetchingSchedule: false,
    isUpdatingSchedule: false,
    isUpdatingBooking: false,
  },
};

export const getters = {
  getProviders: _state => _state.providers,
  getServices: _state => _state.services,
  getBookings: _state => _state.bookings,
  getUIFlags: _state => _state.uiFlags,
  getProviderById: _state => id => {
    return _state.providers.find(record => record.id === Number(id)) || {};
  },
  getServiceById: _state => id => {
    return _state.services.find(record => record.id === Number(id)) || {};
  },
  getBookingById: _state => id => {
    return _state.bookings.find(record => record.id === Number(id)) || {};
  },
  getSchedule: _state => _state.schedule,
  getCalendarBookings: _state => _state.calendarBookings,
  getCalendarProviders: _state => _state.calendarProviders,
};

export const actions = {
  // Providers
  fetchProviders: async ({ commit }) => {
    commit(types.SET_SERVICE_PROVIDER_UI_FLAG, { isFetchingProviders: true });
    try {
      const response = await ProvidersAPI.get();
      commit(types.SET_SERVICE_PROVIDERS, response.data);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SERVICE_PROVIDER_UI_FLAG, {
        isFetchingProviders: false,
      });
    }
  },

  createProvider: async ({ commit }, data) => {
    commit(types.SET_SERVICE_PROVIDER_UI_FLAG, { isCreatingProvider: true });
    try {
      const response = await ProvidersAPI.create(data);
      commit(types.ADD_SERVICE_PROVIDER, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SERVICE_PROVIDER_UI_FLAG, { isCreatingProvider: false });
    }
  },

  updateProvider: async ({ commit }, { id, ...data }) => {
    commit(types.SET_SERVICE_PROVIDER_UI_FLAG, { isUpdatingProvider: true });
    try {
      const response = await ProvidersAPI.update(id, data);
      commit(types.EDIT_SERVICE_PROVIDER, response.data);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SERVICE_PROVIDER_UI_FLAG, { isUpdatingProvider: false });
    }
  },

  deleteProvider: async ({ commit }, id) => {
    commit(types.SET_SERVICE_PROVIDER_UI_FLAG, { isDeletingProvider: true });
    try {
      await ProvidersAPI.delete(id);
      commit(types.DELETE_SERVICE_PROVIDER, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SERVICE_PROVIDER_UI_FLAG, { isDeletingProvider: false });
    }
  },

  // Services
  fetchServices: async ({ commit }) => {
    commit(types.SET_SERVICE_UI_FLAG, { isFetchingServices: true });
    try {
      const response = await ServicesAPI.get();
      commit(types.SET_SERVICES, response.data);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SERVICE_UI_FLAG, { isFetchingServices: false });
    }
  },

  createService: async ({ commit }, data) => {
    commit(types.SET_SERVICE_UI_FLAG, { isCreatingService: true });
    try {
      const response = await ServicesAPI.create(data);
      commit(types.ADD_SERVICE, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SERVICE_UI_FLAG, { isCreatingService: false });
    }
  },

  updateService: async ({ commit }, { id, ...data }) => {
    commit(types.SET_SERVICE_UI_FLAG, { isUpdatingService: true });
    try {
      const response = await ServicesAPI.update(id, data);
      commit(types.EDIT_SERVICE, response.data);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SERVICE_UI_FLAG, { isUpdatingService: false });
    }
  },

  deleteService: async ({ commit }, id) => {
    commit(types.SET_SERVICE_UI_FLAG, { isDeletingService: true });
    try {
      await ServicesAPI.delete(id);
      commit(types.DELETE_SERVICE, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SERVICE_UI_FLAG, { isDeletingService: false });
    }
  },

  // Bookings
  fetchBookings: async ({ commit }, params = {}) => {
    commit(types.SET_SERVICE_BOOKING_UI_FLAG, { isFetchingBookings: true });
    try {
      const response = await BookingsAPI.get(params);
      commit(types.SET_SERVICE_BOOKINGS, response.data);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SERVICE_BOOKING_UI_FLAG, { isFetchingBookings: false });
    }
  },

  createBooking: async ({ commit }, data) => {
    commit(types.SET_SERVICE_BOOKING_UI_FLAG, { isCreatingBooking: true });
    try {
      const response = await BookingsAPI.create(data);
      commit(types.ADD_SERVICE_BOOKING, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SERVICE_BOOKING_UI_FLAG, { isCreatingBooking: false });
    }
  },

  cancelBooking: async ({ commit }, { id, reason }) => {
    try {
      const response = await BookingsAPI.cancel(id, reason);
      commit(types.EDIT_SERVICE_BOOKING, response.data);
    } catch (error) {
      throw new Error(error);
    }
  },

  updateBooking: async ({ commit }, { id, ...data }) => {
    commit(types.SET_SERVICE_BOOKING_UI_FLAG, { isUpdatingBooking: true });
    try {
      const response = await BookingsAPI.update(id, data);
      commit(types.EDIT_SERVICE_BOOKING, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SERVICE_BOOKING_UI_FLAG, { isUpdatingBooking: false });
    }
  },

  // Schedule
  fetchSchedule: async ({ commit }) => {
    commit(types.SET_CALENDAR_UI_FLAG, { isFetchingSchedule: true });
    try {
      const response = await ScheduleAPI.show();
      commit(types.SET_SERVICE_SCHEDULE, response.data);
      return response.data;
    } catch (error) {
      if (error.response?.status !== 404) {
        throw new Error(error);
      }
      return null;
    } finally {
      commit(types.SET_CALENDAR_UI_FLAG, { isFetchingSchedule: false });
    }
  },

  updateSchedule: async ({ commit }, data) => {
    commit(types.SET_CALENDAR_UI_FLAG, { isUpdatingSchedule: true });
    try {
      const response = await ScheduleAPI.update({ schedule: data });
      commit(types.SET_SERVICE_SCHEDULE, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_CALENDAR_UI_FLAG, { isUpdatingSchedule: false });
    }
  },

  createSchedule: async ({ commit }, data) => {
    commit(types.SET_CALENDAR_UI_FLAG, { isUpdatingSchedule: true });
    try {
      const response = await ScheduleAPI.create({ schedule: data });
      commit(types.SET_SERVICE_SCHEDULE, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_CALENDAR_UI_FLAG, { isUpdatingSchedule: false });
    }
  },

  // Provider Schedule
  fetchProviderSchedule: async ({ commit }, providerId) => {
    commit(types.SET_CALENDAR_UI_FLAG, { isFetchingSchedule: true });
    try {
      const response = await ProviderScheduleAPI.getSchedule(providerId);
      return response.data;
    } catch (error) {
      if (error.response?.status !== 404) {
        throw new Error(error);
      }
      return null;
    } finally {
      commit(types.SET_CALENDAR_UI_FLAG, { isFetchingSchedule: false });
    }
  },

  updateProviderSchedule: async (
    { commit, state: moduleState },
    { providerId, data }
  ) => {
    commit(types.SET_CALENDAR_UI_FLAG, { isUpdatingSchedule: true });
    try {
      const existingSchedule = moduleState.providers.find(
        p => p.id === providerId
      )?.provider_schedule;
      let response;
      if (existingSchedule) {
        response = await ProviderScheduleAPI.updateSchedule(providerId, data);
      } else {
        response = await ProviderScheduleAPI.createSchedule(providerId, data);
      }
      const providerIndex = moduleState.providers.findIndex(
        p => p.id === providerId
      );
      if (providerIndex !== -1) {
        const updatedProviders = [...moduleState.providers];
        updatedProviders[providerIndex] = {
          ...updatedProviders[providerIndex],
          provider_schedule: response.data,
        };
        commit(types.SET_SERVICE_PROVIDERS, updatedProviders);
      }
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_CALENDAR_UI_FLAG, { isUpdatingSchedule: false });
    }
  },

  // Calendar
  fetchCalendar: async ({ commit }, params = {}) => {
    commit(types.SET_CALENDAR_UI_FLAG, { isFetchingCalendar: true });
    try {
      const response = await BookingsAPI.getCalendar(params);
      commit(types.SET_CALENDAR_BOOKINGS, response.data.bookings || []);
      commit(types.SET_CALENDAR_PROVIDERS, response.data.providers || []);
      commit(types.SET_SERVICE_SCHEDULE, response.data.schedule);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_CALENDAR_UI_FLAG, { isFetchingCalendar: false });
    }
  },
};

export const mutations = {
  [types.SET_SERVICE_PROVIDER_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_SERVICE_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_SERVICE_BOOKING_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },

  [types.SET_SERVICE_PROVIDERS]: createSetMutation('providers'),
  [types.ADD_SERVICE_PROVIDER]: createCreateMutation('providers'),
  [types.EDIT_SERVICE_PROVIDER]: createUpdateMutation('providers'),
  [types.DELETE_SERVICE_PROVIDER]: createDestroyMutation('providers'),

  [types.SET_SERVICES]: createSetMutation('services'),
  [types.ADD_SERVICE]: createCreateMutation('services'),
  [types.EDIT_SERVICE]: createUpdateMutation('services'),
  [types.DELETE_SERVICE]: createDestroyMutation('services'),

  [types.SET_SERVICE_BOOKINGS]: createSetMutation('bookings'),
  [types.ADD_SERVICE_BOOKING]: createCreateMutation('bookings'),
  [types.EDIT_SERVICE_BOOKING]: createUpdateMutation('bookings'),
  [types.DELETE_SERVICE_BOOKING]: createDestroyMutation('bookings'),

  [types.SET_SERVICE_SCHEDULE]: createSetMutation('schedule'),
  [types.SET_CALENDAR_BOOKINGS]: createSetMutation('calendarBookings'),
  [types.SET_CALENDAR_PROVIDERS]: createSetMutation('calendarProviders'),
  [types.SET_CALENDAR_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
