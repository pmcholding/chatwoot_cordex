/* global axios */
import ApiClient from './ApiClient';

class AccountAPI extends ApiClient {
  constructor() {
    super('', { accountScoped: false }); // Changed to false to avoid double account scoping
  }

  createAccount(data) {
    return axios.post(`${this.apiVersion}/accounts`, data);
  }

  show(accountId) {
    return axios.get(`${this.apiVersion}/accounts/${accountId}`);
  }

  async getCacheKeys() {
    const response = await axios.get(
      `/api/v1/accounts/${this.accountIdFromRoute}/cache_keys`
    );
    return response.data.cache_keys;
  }
}

export default new AccountAPI();
