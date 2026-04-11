import ApiClient from './ApiClient';

class ProvidersAPI extends ApiClient {
  constructor() {
    super('services/providers', { accountScoped: true });
  }
}

export default new ProvidersAPI();
