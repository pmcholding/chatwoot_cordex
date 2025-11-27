import KanbanAPI from '../../api/kanban';

const state = {
  stages: [],
  cardsByStage: {}, // { [stageId]: { items: [], loading: false, hasMore: true } }
  filters: {
    q: '',
    inbox_id: null,
    assignee_id: null,
    label_ids: [],
    created_after: null,
    created_before: null,
  },
  ui: { isLoading: false },
};

export const getters = {
  orderedStages: $state =>
    [...$state.stages].sort((a, b) => a.position - b.position),
  cardsForStage: $state => stageId => $state.cardsByStage[stageId]?.items || [],
  loadingForStage: $state => stageId =>
    $state.cardsByStage[stageId]?.loading || false,
  hasMoreForStage: $state => stageId =>
    $state.cardsByStage[stageId]?.hasMore || false,
  filters: $state => $state.filters,
};

export const actions = {
  async fetchInitial({ commit, state: currentState }) {
    commit('SET_LOADING', true);
    try {
      const response = await KanbanAPI.getBoardData(currentState.filters);
      const {
        stages,
        conversations_by_stage,
        has_more_by_stage,
        total_counts_by_stage,
      } = response.data;

      // Set stages with total counts from backend
      const stagesWithCounts = stages.map(stage => ({
        ...stage,
        count: total_counts_by_stage?.[stage.id] || 0,
      }));
      commit('SET_STAGES', stagesWithCounts);

      // Transform conversations_by_stage to match our store structure
      const grouped = stages.reduce((acc, stage) => {
        acc[stage.id] = {
          items: conversations_by_stage[stage.id] || [],
          loading: false,
          hasMore: has_more_by_stage?.[stage.id] || false,
          totalCount: total_counts_by_stage?.[stage.id] || 0,
        };
        return acc;
      }, {});

      // Add unassigned conversations
      grouped.unassigned = {
        items: conversations_by_stage.unassigned || [],
        loading: false,
        hasMore: has_more_by_stage?.unassigned || false,
        totalCount: total_counts_by_stage?.unassigned || 0,
      };

      commit('SET_ALL_CARDS', grouped);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('Error fetching kanban data:', error);
      // Fallback to empty state
      commit('SET_STAGES', []);
      commit('SET_ALL_CARDS', {});
    } finally {
      commit('SET_LOADING', false);
    }
  },

  async loadMore({ commit, state: currentState }, stageId) {
    const stageData = currentState.cardsByStage[stageId];
    if (!stageData || !stageData.hasMore || stageData.loading) return;

    commit('SET_STAGE_LOADING', { stageId, loading: true });

    try {
      // Calculate next page based on current items
      const currentItems = stageData.items.length;
      const perPage = 15;
      const nextPage = Math.floor(currentItems / perPage) + 1;

      const response = await KanbanAPI.getStageConversations(
        stageId,
        nextPage,
        currentState.filters
      );

      const { conversations, has_more } = response.data;

      commit('APPEND_STAGE_ITEMS', { stageId, items: conversations });
      commit('SET_STAGE_HAS_MORE', { stageId, hasMore: has_more });
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('Error loading more conversations:', error);
    } finally {
      commit('SET_STAGE_LOADING', { stageId, loading: false });
    }
  },

  async moveCard({ commit }, { cardId, fromStageId, toStageId, toIndex }) {
    try {
      // Optimistic update
      commit('MOVE_CARD', { cardId, fromStageId, toStageId, toIndex });
      commit('UPDATE_STAGE_COUNTS', { fromStageId, toStageId });

      // API call
      await KanbanAPI.moveConversation(cardId, toStageId);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('Error moving conversation:', error);
      // Rollback optimistic update
      commit('MOVE_CARD', {
        cardId,
        fromStageId: toStageId,
        toStageId: fromStageId,
        toIndex: 0,
      });
      commit('UPDATE_STAGE_COUNTS', {
        fromStageId: toStageId,
        toStageId: fromStageId,
      });
      throw error;
    }
  },

  async createStage({ commit }, { name, color }) {
    try {
      const response = await KanbanAPI.createStage({ name, color });
      const newStage = response.data;
      commit('ADD_STAGE', newStage);
      return newStage;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('Error creating stage:', error);
      throw error;
    }
  },

  async updateStage({ commit }, { id, name, color }) {
    try {
      const response = await KanbanAPI.updateStage(id, { name, color });
      const updatedStage = response.data;
      commit('EDIT_STAGE', updatedStage);
      return updatedStage;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('Error updating stage:', error);
      throw error;
    }
  },

  async deleteStage({ commit }, { id }) {
    try {
      await KanbanAPI.deleteStage(id);
      commit('DELETE_STAGE', { id });
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('Error deleting stage:', error);
      throw error;
    }
  },

  async reorderStages(_, positions) {
    try {
      await KanbanAPI.reorderStages(positions);
      // The positions should already be updated in the UI
      // If needed, we could refetch the stages here
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('Error reordering stages:', error);
      throw error;
    }
  },

  async setFilter({ commit, dispatch }, payload) {
    commit('SET_FILTER', payload);
    // Refetch data with new filters
    await dispatch('fetchInitial');
  },
};

export const mutations = {
  SET_LOADING($state, flag) {
    $state.ui.isLoading = flag;
  },
  SET_STAGES($state, stages) {
    $state.stages = stages;
  },
  SET_ALL_CARDS($state, grouped) {
    $state.cardsByStage = grouped;
  },
  SET_STAGE_LOADING($state, { stageId, loading }) {
    $state.cardsByStage[stageId].loading = loading;
  },
  SET_STAGE_HAS_MORE($state, { stageId, hasMore }) {
    if ($state.cardsByStage[stageId]) {
      $state.cardsByStage[stageId].hasMore = hasMore;
    }
  },
  APPEND_STAGE_ITEMS($state, { stageId, items }) {
    if ($state.cardsByStage[stageId]) {
      $state.cardsByStage[stageId].items.push(...items);
    }
  },
  MOVE_CARD($state, { cardId, fromStageId, toStageId, toIndex }) {
    const from = $state.cardsByStage[fromStageId]?.items || [];
    const to = $state.cardsByStage[toStageId]?.items || [];
    const idx = from.findIndex(c => c.id === cardId);
    if (idx === -1) return;
    const [card] = from.splice(idx, 1);
    card.kanban_stage_id = toStageId;
    if (typeof toIndex === 'number' && toIndex >= 0 && toIndex <= to.length) {
      to.splice(toIndex, 0, card);
    } else {
      to.push(card);
    }
  },
  ADD_STAGE($state, stage) {
    $state.stages.push(stage);
    $state.cardsByStage[stage.id] = {
      items: [],
      loading: false,
      hasMore: false,
    };
  },
  EDIT_STAGE($state, updatedStage) {
    const idx = $state.stages.findIndex(s => s.id === updatedStage.id);
    if (idx !== -1) {
      $state.stages.splice(idx, 1, updatedStage);
    }
  },
  DELETE_STAGE($state, { id }) {
    $state.stages = $state.stages.filter(s => s.id !== id);
    delete $state.cardsByStage[id];
  },
  SET_FILTER($state, payload) {
    $state.filters = { ...$state.filters, ...payload };
  },
  UPDATE_STAGE_COUNTS($state, { fromStageId, toStageId }) {
    // Decrement count in source stage
    const fromStage = $state.stages.find(s => s.id === fromStageId);
    if (fromStage && fromStage.count > 0) {
      fromStage.count -= 1;
    }
    if ($state.cardsByStage[fromStageId]?.totalCount > 0) {
      $state.cardsByStage[fromStageId].totalCount -= 1;
    }

    // Increment count in destination stage
    const toStage = $state.stages.find(s => s.id === toStageId);
    if (toStage) {
      toStage.count = (toStage.count || 0) + 1;
    }
    if ($state.cardsByStage[toStageId]) {
      $state.cardsByStage[toStageId].totalCount =
        ($state.cardsByStage[toStageId].totalCount || 0) + 1;
    }
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
