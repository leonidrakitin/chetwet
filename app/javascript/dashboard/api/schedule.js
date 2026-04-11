import ApiClient from './ApiClient';

class ScheduleAPI extends ApiClient {
  constructor() {
    super('services/schedule', { accountScoped: true });
  }
}

export default new ScheduleAPI();
