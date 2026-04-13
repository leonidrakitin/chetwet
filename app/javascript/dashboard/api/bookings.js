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

  getCalendar(params) {
    return axios.get(`${this.url}/calendar`, { params });
  }

  confirm(id) {
    return axios.post(`${this.url}/${id}/confirm`);
  }

  cancel(id, reason) {
    return axios.post(`${this.url}/${id}/cancel`, { reason });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, data);
  }
}

export default new BookingsAPI();
