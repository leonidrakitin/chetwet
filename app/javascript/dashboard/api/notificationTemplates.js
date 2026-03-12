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
}

export default new NotificationTemplatesAPI();
