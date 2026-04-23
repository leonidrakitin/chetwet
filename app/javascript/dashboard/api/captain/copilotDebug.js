/* global axios */
import ApiClient from '../ApiClient';

class CopilotDebug extends ApiClient {
  constructor() {
    super('captain/copilot_debug', { accountScoped: true });
  }

  get(threadId) {
    return axios.get(`${this.url}/${threadId}`);
  }
}

export default new CopilotDebug();
