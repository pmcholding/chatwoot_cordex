/* global axios */
import ApiClient from './ApiClient';

class KanbanAPI extends ApiClient {
  constructor() {
    super('kanban_stages', { accountScoped: true });
  }

  // Get all kanban stages with conversation counts
  getStages(includeConversationCounts = true) {
    return axios.get(`${this.url}`, {
      params: { include_counts: includeConversationCounts },
    });
  }

  // Get kanban board data with conversations (paginated)
  getBoardData(filters = {}) {
    return axios.get(`${this.url}/board_data`, {
      params: { ...filters, per_page: 15 },
    });
  }

  // Get more conversations for a specific stage (pagination)
  getStageConversations(stageId, page = 1, filters = {}) {
    return axios.get(`${this.url}/${stageId}/stage_conversations`, {
      params: { page, per_page: 15, ...filters },
    });
  }

  // Create a new kanban stage
  createStage(stageData) {
    return axios.post(`${this.url}`, {
      kanban_stage: stageData,
    });
  }

  // Update a kanban stage
  updateStage(id, stageData) {
    return axios.patch(`${this.url}/${id}`, {
      kanban_stage: stageData,
    });
  }

  // Delete a kanban stage
  deleteStage(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  // Reorder kanban stages
  reorderStages(positions) {
    return axios.patch(`${this.url}/reorder`, {
      positions: positions,
    });
  }

  // Move a conversation to a different stage
  moveConversation(conversationId, stageId) {
    return axios.patch(
      `${this.baseUrl()}/conversations/${conversationId}/kanban/move`,
      {
        kanban_stage_id: stageId,
      }
    );
  }

  // Bulk move conversations
  bulkMoveConversations(conversationIds, stageId) {
    return axios.patch(`${this.baseUrl()}/conversations/kanban/bulk_move`, {
      conversation_ids: conversationIds,
      kanban_stage_id: stageId,
    });
  }
}

export default new KanbanAPI();
