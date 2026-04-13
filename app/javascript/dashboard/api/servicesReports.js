import ApiClient from './ApiClient';

class ServicesReportsAPI extends ApiClient {
  constructor() {
    super('services/reports', { accountScoped: true });
  }

  getReports(params = {}) {
    return this.get('', params);
  }
}

export default new ServicesReportsAPI();
