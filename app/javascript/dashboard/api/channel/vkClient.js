/* global axios */
import ApiClient from '../ApiClient';

class VkChannel extends ApiClient {
  constructor() {
    super('vk', { accountScoped: true });
  }

  exchangeCode(payload) {
    return axios.post(`${this.url}/authorization`, payload);
  }

  getGroups(tokenHandle) {
    return axios.get(`${this.url}/groups`, {
      params: { token_handle: tokenHandle },
    });
  }
}

export default new VkChannel();
