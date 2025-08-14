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

  getAgentTemplates() {
    return axios.get(`${this.url.replace('/agents', '/agent_templates')}`);
  }
}

export default new Agents();
