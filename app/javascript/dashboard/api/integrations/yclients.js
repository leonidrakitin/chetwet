/* global axios */

import ApiClient from '../ApiClient';

class YclientsAPI extends ApiClient {
  constructor() {
    super('integrations/yclients', { accountScoped: true });
  }

  getRecords(contactId, companyId = null) {
    return axios.get(`${this.url}/contacts/${contactId}/records`, {
      params: companyId ? { company_id: companyId } : {},
    });
  }

  getFinances(contactId, companyId = null) {
    return axios.get(`${this.url}/contacts/${contactId}/finances`, {
      params: companyId ? { company_id: companyId } : {},
    });
  }

  syncContacts(companyId = null) {
    return axios.post(
      `${this.url}/sync_contacts`,
      companyId ? { company_id: companyId } : {}
    );
  }
}

export default new YclientsAPI();
