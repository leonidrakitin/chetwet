/* global axios */
import ApiClient from '../ApiClient';

class CaptainAssistantTemplate extends ApiClient {
  constructor() {
    super('captain/assistant_templates', { accountScoped: true });
  }

  list({ locale } = {}) {
    return axios.get(this.url, { params: { locale } });
  }

  createAssistant({ templateId, productName, locale, name, adapted_data }) {
    const templatePayload = {
      template_id: templateId,
      product_name: productName,
      locale,
      name,
    };
    if (adapted_data) {
      templatePayload.adapted_data = adapted_data;
    }
    return axios.post(`${this.url}/create_assistant`, {
      template: templatePayload,
    });
  }

  getClarifyingQuestions({ templateId, locale }) {
    return axios.get(`${this.url}/clarifying_questions`, {
      params: { template_id: templateId, locale },
    });
  }

  adapt({ templateId, clarifications, locale }) {
    return axios.post(`${this.url}/adapt`, {
      template_id: templateId,
      locale,
      clarifications,
    });
  }
}

export default new CaptainAssistantTemplate();
