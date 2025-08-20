/* global axios */
import ApiClient from './ApiClient';

class EvolutionWhatsappAPI extends ApiClient {
  constructor() {
    super('evolution_whatsapp', { accountScoped: true });
  }

  // Get inbox ID from current route
  // eslint-disable-next-line class-methods-use-this
  get inboxIdFromRoute() {
    const pathname = window.location.pathname;

    // Handle inbox creation flow: /app/accounts/1/settings/inboxes/new/{inbox_id}/finish
    if (pathname.includes('/inboxes/new/')) {
      const pathParts = pathname.split('/');
      const newIndex = pathParts.indexOf('new');
      if (
        newIndex !== -1 &&
        pathParts[newIndex + 1] &&
        pathParts[newIndex + 1] !== 'finish'
      ) {
        return pathParts[newIndex + 1];
      }
    }

    // Handle regular inbox URLs: /app/accounts/1/inboxes/{inbox_id}
    if (pathname.includes('/inboxes/')) {
      const pathParts = pathname.split('/');
      const inboxIndex = pathParts.indexOf('inboxes');
      if (inboxIndex !== -1 && pathParts[inboxIndex + 1]) {
        return pathParts[inboxIndex + 1];
      }
    }

    return null;
  }

  // Override url to include inbox_id
  get url() {
    const inboxId = this.inboxIdFromRoute;
    if (inboxId) {
      return `${this.baseUrl()}/inboxes/${inboxId}/${this.resource}`;
    }
    return `${this.baseUrl()}/${this.resource}`;
  }

  initializeInstance() {
    return axios.post(`${this.url}/initialize_instance`);
  }

  getConnectionStatus() {
    return axios.get(`${this.url}/connection_status`);
  }

  connectQRCode() {
    return axios.post(`${this.url}/connect_qr_code`);
  }

  connectWithNumber(phoneNumber) {
    return axios.post(`${this.url}/connect_with_number`, {
      phone_number: phoneNumber,
    });
  }

  disconnect() {
    return axios.delete(`${this.url}/disconnect`);
  }

  updateSettings(settings) {
    return axios.patch(`${this.url}/update_settings`, {
      settings,
    });
  }

  getInstanceSettings() {
    return axios.get(`${this.url}/instance_settings`);
  }

  getWebhookInfo() {
    return axios.get(`${this.url}/webhook_info`);
  }
}

export default new EvolutionWhatsappAPI();
