/* global axios */

import ApiClient from './ApiClient';

class BookingsAPI extends ApiClient {
  constructor() {
    super('services/bookings', { accountScoped: true });
  }

  getAvailableSlots(params) {
    return axios.get(`${this.url}/available_slots`, { params });
  }

  getUpcoming() {
    return axios.get(`${this.url}/upcoming`);
  }

  confirm(id) {
    return axios.post(`${this.url}/${id}/confirm`);
  }

  cancel(id, reason) {
    return axios.post(`${this.url}/${id}/cancel`, { reason });
  }
}

export default new BookingsAPI();
