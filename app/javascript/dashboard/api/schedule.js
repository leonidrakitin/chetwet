/* global axios */
import ApiClient from './ApiClient';

class ScheduleAPI extends ApiClient {
  constructor() {
    super('services/schedule', { accountScoped: true });
  }

  show() {
    return axios.get(this.url);
  }

  update(data) {
    return axios.patch(this.url, data);
  }
}

export default new ScheduleAPI();
