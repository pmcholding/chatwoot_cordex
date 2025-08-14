/* global axios */

import ApiClient from '../ApiClient';

/**
 * Represents the data object for a OpenAI hook.
 * @typedef {Object} ConversationMessageData
 * @property {string} [tone] - The tone of the message.
 * @property {string} [content] - The content of the message.
 * @property {string} [conversation_display_id] - The display ID of the conversation (optional).
 */

/**
 * A client for the OpenAI API.
 * @extends ApiClient
 */
class OpenAIAPI extends ApiClient {
  /**
   * Creates a new OpenAIAPI instance.
   */
  constructor() {
    super('integrations', { accountScoped: true });

    /**
     * The conversation events supported by the API.
     * @type {string[]}
     */
    this.conversation_events = [
      'summarize',
      'reply_suggestion',
      'label_suggestion',
    ];

    /**
     * The message events supported by the API.
     * @type {string[]}
     */
    this.message_events = ['rephrase'];

    /**
     * The instruction generation events supported by the API.
     * @type {string[]}
     */
    this.instruction_events = ['agent_instruction_generator'];
  }

  /**
   * Processes an event using the OpenAI API.
   * @param {Object} options - The options for the event.
   * @param {string} [options.type='rephrase'] - The type of event to process.
   * @param {string} [options.content] - The content of the event.
   * @param {string} [options.tone] - The tone of the event.
   * @param {string} [options.conversationId] - The ID of the conversation to process the event for.
   * @param {Array} [options.conversationHistory] - The conversation history for instruction generation.
   * @param {string} options.hookId - The ID of the hook to use for processing the event.
   * @returns {Promise} A promise that resolves with the result of the event processing.
   */
  processEvent({
    type = 'rephrase',
    content,
    tone,
    conversationId,
    conversationHistory,
    hookId,
  }) {
    /**
     * @type {ConversationMessageData}
     */
    let data = {
      tone,
      content,
    };

    if (this.conversation_events.includes(type)) {
      data = {
        conversation_display_id: conversationId,
      };
    }

    if (this.instruction_events.includes(type)) {
      data = {
        conversation_history: conversationHistory || [],
        user_input: content || '',
      };
    }

    return axios.post(`${this.url}/hooks/${hookId}/process_event`, {
      event: {
        name: type,
        data,
      },
    });
  }
}

export default new OpenAIAPI();
