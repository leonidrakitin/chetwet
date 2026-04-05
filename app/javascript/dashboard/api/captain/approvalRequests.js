import ApiClient from '../ApiClient';

class ApprovalRequests extends ApiClient {
  constructor() {
    super('captain/approval_requests', { accountScoped: true });
  }

  update(id, { selectedOptionIndex, customResponse }) {
    return this.patch(id, {
      selected_option_index: selectedOptionIndex,
      custom_response: customResponse,
    });
  }
}

export default new ApprovalRequests();
