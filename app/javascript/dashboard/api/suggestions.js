/* global axios */
import ApiClient from './ApiClient';

class SuggestionsAPI extends ApiClient {
  constructor() {
    super('suggestions', { accountScoped: true });
  }

  vote(id, voteType) {
    return axios.post(`${this.url}/${id}/vote`, { vote_type: voteType });
  }

  addTag(id, tag) {
    return axios.post(`${this.url}/${id}/add_tag`, { tag });
  }

  removeTag(id, tag) {
    return axios.delete(`${this.url}/${id}/remove_tag`, { data: { tag } });
  }
}

export default new SuggestionsAPI();
