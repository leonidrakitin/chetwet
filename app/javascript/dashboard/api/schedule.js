import ApiClient from './ApiClient';

class ScheduleAPI extends ApiClient {
  constructor() {
    super('services/schedule', { accountScoped: true });
  }

  show() {
    return this.get();
  }

  update(data) {
    return this.patch(data);
  }

  create(data) {
    return this.post(data);
  }
}

export default new ScheduleAPI();
