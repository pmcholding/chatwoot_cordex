/* global axios */
import ApiClient from '../ApiClient';

class ScheduledMessageApi extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  list({ conversationId }) {
    return axios.get(`${this.url}/${conversationId}/scheduled_messages`);
  }

  cancel({ conversationId, id }) {
    return axios.delete(
      `${this.url}/${conversationId}/scheduled_messages/${id}`
    );
  }
}

export default new ScheduledMessageApi();
