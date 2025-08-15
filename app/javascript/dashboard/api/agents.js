/* global axios */

import ApiClient from './ApiClient';

class Agents extends ApiClient {
  constructor() {
    super('agents', { accountScoped: true });
  }

  bulkInvite({ emails }) {
    return axios.post(`${this.url}/bulk_create`, {
      emails,
    });
  }

  getAgentTemplates(language = null) {
    const params = {};
    if (language) {
      params.language = language;
    }
    return axios.get(`${this.url.replace('/agents', '/agent_templates')}`, {
      params,
    });
  }
}

export default new Agents();
