/* global axios */
import ApiClient from '../ApiClient';

class CaptainAssistantTemplate extends ApiClient {
  constructor() {
    super('captain/assistant_templates', { accountScoped: true });
  }

  list({ locale } = {}) {
    return axios.get(this.url, { params: { locale } });
  }

  createAssistant({ templateId, productName, locale, name }) {
    return axios.post(`${this.url}/create_assistant`, {
      template: {
        template_id: templateId,
        product_name: productName,
        locale,
        name,
      },
    });
  }
}

export default new CaptainAssistantTemplate();
