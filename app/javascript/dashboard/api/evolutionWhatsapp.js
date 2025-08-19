/* global axios */
import ApiClient from './ApiClient';

class EvolutionWhatsappAPI extends ApiClient {
  constructor() {
    super('evolution_whatsapp', { accountScoped: true });
  }

  // Get inbox ID from current route
  static getInboxIdFromRoute() {
    const isInsideInboxScopedURLs = window.location.pathname.includes(
      '/inboxes/'
    );

    if (isInsideInboxScopedURLs) {
      const pathParts = window.location.pathname.split('/');
      const inboxIndex = pathParts.indexOf('inboxes');
      if (inboxIndex !== -1 && pathParts[inboxIndex + 1]) {
        return pathParts[inboxIndex + 1];
      }
    }
    return null;
  }

  initializeInstance(inboxId) {
    return axios.post(`${this.url}/${inboxId}/initialize`);
  }

  getConnectionStatus(inboxId) {
    return axios.get(`${this.url}/${inboxId}/status`);
  }

  connectWithQRCode(inboxId) {
    return axios.post(`${this.url}/${inboxId}/connect_qr`);
  }

  connectWithPhoneNumber(inboxId, phoneNumber) {
    return axios.post(`${this.url}/${inboxId}/connect_phone`, {
      phone_number: phoneNumber,
    });
  }

  disconnect(inboxId) {
    return axios.post(`${this.url}/${inboxId}/disconnect`);
  }

  updateSettings(inboxId, settings) {
    return axios.put(`${this.url}/${inboxId}/settings`, { settings });
  }
}

export default new EvolutionWhatsappAPI();
