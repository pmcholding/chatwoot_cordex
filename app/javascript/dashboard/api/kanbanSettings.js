/* global axios */
import ApiClient from './ApiClient';

class KanbanSettingsAPI extends ApiClient {
  constructor() {
    super('kanban_settings', { accountScoped: true });
  }

  getSettings() {
    return axios.get(`${this.url}`);
  }

  updateSettings(params) {
    return axios.patch(`${this.url}`, params);
  }
}

export default new KanbanSettingsAPI();
