/* global axios */
import ApiClient from '../ApiClient';

class Insights extends ApiClient {
  constructor() {
    super('captain/insights', { accountScoped: true });
  }

  fetch({ days = 30, assistantId } = {}) {
    return axios.get(this.url, { params: { days, assistant_id: assistantId } });
  }
}

export default new Insights();
