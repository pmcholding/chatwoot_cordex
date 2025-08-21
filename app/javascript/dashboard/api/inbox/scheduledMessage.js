/* global axios */
import ApiClient from '../ApiClient'

class ScheduledMessageAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true })
  }

  create(conversationId, messageData) {
    return axios.post(
      `${this.url}/${conversationId}/scheduled_messages`,
      messageData
    )
  }

  list(conversationId) {
    return axios.get(
      `${this.url}/${conversationId}/scheduled_messages`
    )
  }

  cancel(conversationId, messageId) {
    return axios.delete(
      `${this.url}/${conversationId}/scheduled_messages/${messageId}`
    )
  }
}

export default new ScheduledMessageAPI()
