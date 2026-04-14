import ApiClient from './ApiClient';

class ProviderScheduleAPI extends ApiClient {
  constructor() {
    super('services/providers', { accountScoped: true });
  }

  getSchedule(providerId) {
    return this.get(`${providerId}/schedule`);
  }

  createSchedule(providerId, data) {
    return this.post(`${providerId}/schedule`, { provider_schedule: data });
  }

  updateSchedule(providerId, data) {
    return this.patch(`${providerId}/schedule`, { provider_schedule: data });
  }

  deleteSchedule(providerId) {
    return this.delete(`${providerId}/schedule`);
  }
}

export default new ProviderScheduleAPI();
