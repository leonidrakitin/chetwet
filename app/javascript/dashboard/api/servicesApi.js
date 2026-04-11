import ApiClient from './ApiClient';

class ServicesAPI extends ApiClient {
  constructor() {
    super('services/services', { accountScoped: true });
  }
}

export default new ServicesAPI();
