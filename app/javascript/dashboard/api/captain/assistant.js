/* global axios */
import ApiClient from '../ApiClient';

class CaptainAssistant extends ApiClient {
  constructor() {
    super('captain/assistants', { accountScoped: true });
  }

  get({ page = 1, searchKey } = {}) {
    return axios.get(this.url, {
      params: {
        page,
        searchKey,
      },
    });
  }

  playground({ assistantId, messageContent, messageHistory }) {
    return axios.post(`${this.url}/${assistantId}/playground`, {
      message_content: messageContent,
      message_history: messageHistory,
    });
  }

  getBuiltInTools(assistantId) {
    return axios.get(`${this.url}/${assistantId}/built_in_tools`);
  }

  updateDisabledBuiltInTools(assistantId, disabledToolIds) {
    return axios.put(`${this.url}/${assistantId}`, {
      assistant: {
        config: { disabled_built_in_tools: disabledToolIds },
      },
    });
  }
}

export default new CaptainAssistant();
