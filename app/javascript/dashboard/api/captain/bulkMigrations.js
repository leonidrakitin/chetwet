/* global axios */
import ApiClient from '../ApiClient';

class CaptainBulkMigrations extends ApiClient {
  constructor() {
    super('captain/bulk_migrations', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }

  create(formData) {
    return axios.post(this.url, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
  }
}

export default new CaptainBulkMigrations();
