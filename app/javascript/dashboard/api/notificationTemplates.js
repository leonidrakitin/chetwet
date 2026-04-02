/* global axios */

import ApiClient from './ApiClient';

class NotificationTemplatesAPI extends ApiClient {
  constructor() {
    super('notification_templates', { accountScoped: true });
  }

  clone(id) {
    return axios.post(`${this.url}/${id}/clone`);
  }

  reorder(notificationTemplates) {
    return axios.post(`${this.url}/reorder`, {
      notification_templates: notificationTemplates,
    });
  }

  cascadeSettings() {
    return axios.get(`${this.url}/cascade_settings`);
  }

  updateCascadeSettings(data) {
    return axios.put(`${this.url}/cascade_settings`, {
      cascade_settings: data,
    });
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

export default new NotificationTemplatesAPI();
