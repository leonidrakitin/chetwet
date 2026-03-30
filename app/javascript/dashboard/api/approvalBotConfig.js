/* global axios */
import ApiClient from './ApiClient';

class ApprovalBotConfigAPI extends ApiClient {
  constructor() {
    super('approval_bot_configs', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(data) {
    return axios.post(this.url, data);
  }

  update(channelType, data) {
    return axios.patch(`${this.url}/${channelType}`, data);
  }
}

export default new ApprovalBotConfigAPI();
