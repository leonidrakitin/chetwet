/* global axios */
import ApiClient from './ApiClient';

class ContactSegmentsAPI extends ApiClient {
  constructor() {
    super('contact_segments', { accountScoped: true });
  }

  preview(id) {
    return axios.post(`${this.url}/${id}/preview`);
  }

  previewQuery(query) {
    return axios.post(`${this.url}/preview_query`, { query });
  }

  getChangeLogs(id, page = 1) {
    return axios.get(`${this.url}/${id}/change_logs?page=${page}`);
  }

  getStatistics(id) {
    return axios.get(`${this.url}/${id}/statistics`);
  }

  getDashboard() {
    return axios.get(`${this.url}/dashboard`);
  }
}

export default new ContactSegmentsAPI();
