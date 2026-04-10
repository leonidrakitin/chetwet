/* global axios */
import ApiClient from '../ApiClient';

class ApprovalRequests extends ApiClient {
  constructor() {
    super('captain/approval_requests', { accountScoped: true });
  }

  resolve(id, { selectedOptionIndex, customResponse }) {
    return axios.patch(`${this.url}/${id}`, {
      selected_option_index: selectedOptionIndex,
      custom_response: customResponse,
    });
  }
}

export default new ApprovalRequests();
