/* global axios */

import ApiClient from './ApiClient';

class TelegramSessions extends ApiClient {
  constructor() {
    super('telegram_sessions', { accountScoped: true });
  }

  submitCode(id, code) {
    return axios.post(`${this.url}/${id}/submit_code`, { code });
  }

  submitPassword(id, password) {
    return axios.post(`${this.url}/${id}/submit_password`, { password });
  }

  reconnect(id) {
    return axios.post(`${this.url}/${id}/reconnect`);
  }
}

export default new TelegramSessions();
