/* global axios */

import ApiClient from './ApiClient';

class CampaignsAPI extends ApiClient {
  constructor() {
    super('campaigns', { accountScoped: true });
  }

  statistics() {
    return axios.get(`${this.url}/statistics`);
  }

  sendNow(id) {
    return axios.post(`${this.url}/${id}/send_now`);
  }

  previewAudience(id) {
    return axios.get(`${this.url}/${id}/preview_audience`);
  }
}

export default new CampaignsAPI();
